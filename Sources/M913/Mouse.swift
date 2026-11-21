import Foundation
import IOKit.hid
import UserNotifications
import AppKit

func depura(_ s: String) {
    if ProcessInfo.processInfo.environment["M913_DEBUG"] != nil { FileHandle.standardError.write((s + "\n").data(using: .utf8)!) }
}

enum Conexao: Equatable {
    case desconectado
    case semFio
    case cabo
}

/// Fala com o mouse pelo canal de configuração do receptor.
@MainActor
final class Mouse: ObservableObject {
    @Published private(set) var conexao: Conexao = .desconectado
    @Published private(set) var bateria: Int?            // 0...100, de 10 em 10
    @Published private(set) var carregando = false
    @Published private(set) var atualizadoEm: Date?
    @Published private(set) var config: ConfigMouse?     // o que está gravado no mouse
    @Published var rascunho = ConfigMouse()              // o que está sendo editado
    @Published private(set) var lendo = false
    @Published private(set) var gravando = false
    @Published var aviso: String?
    @Published private(set) var semPermissao = false
    /// O mouse deu sinal de vida (respondeu ou se mexeu). Desligado, o ícone some.
    @Published private(set) var ligado = false
    /// Abrir o app de novo pelo Finder mostra o ícone por um tempo, mesmo com o mouse desligado.
    @Published var mostrarSempre = false
    private var falhas = 0
    private let sistema = BateriaSistema()
    private var ultimoSinal = Date.distantPast

    private let gerente: IOHIDManager
    // Dois canais: o receptor sem fio e o cabo. Com o cabo ligado, o mouse só atende
    // leitura e gravação por ele; a bateria vem melhor pelo receptor.
    private var receptor: IOHIDDevice?
    private var cabo: IOHIDDevice?
    private var canal: IOHIDDevice? { cabo ?? receptor }
    private var canalBateria: IOHIDDevice? { receptor ?? cabo }
    private var temCabo: Bool { cabo != nil }
    private let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: 64)
    private let bufferCabo = UnsafeMutablePointer<UInt8>.allocate(capacity: 64)
    private var esperas: [(id: UUID, sub: UInt8, endereco: Int?, continua: CheckedContinuation<[UInt8]?, Never>)] = []
    private var relogio: Timer?
    private var avisouBaixa = false

    init() {
        gerente = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        IOHIDManagerSetDeviceMatching(gerente, [kIOHIDVendorIDKey: M913.fabricante] as CFDictionary)
        let eu = Unmanaged.passUnretained(self).toOpaque()
        IOHIDManagerRegisterDeviceMatchingCallback(gerente, { ctx, _, _, aparelho in
            let m = Unmanaged<Mouse>.fromOpaque(ctx!).takeUnretainedValue()
            MainActor.assumeIsolated { m.chegou(aparelho) }
        }, eu)
        IOHIDManagerRegisterDeviceRemovalCallback(gerente, { ctx, _, _, aparelho in
            let m = Unmanaged<Mouse>.fromOpaque(ctx!).takeUnretainedValue()
            MainActor.assumeIsolated { m.saiu(aparelho) }
        }, eu)
        IOHIDManagerScheduleWithRunLoop(gerente, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
        IOHIDManagerOpen(gerente, IOOptionBits(kIOHIDOptionsTypeNone))
        // Movimento ou clique do Red Dragon = mouse ligado. Sem ficar perguntando.
        IOHIDManagerRegisterInputValueCallback(gerente, { ctx, _, remetente, valor in
            let m = Unmanaged<Mouse>.fromOpaque(ctx!).takeUnretainedValue()
            let pagina = IOHIDElementGetUsagePage(IOHIDValueGetElement(valor))
            guard pagina == 0x01 || pagina == 0x09 else { return }
            MainActor.assumeIsolated { m.sinalDeVida() }
        }, eu)
        if IOHIDCheckAccess(kIOHIDRequestTypeListenEvent) != kIOHIDAccessTypeGranted {
            _ = IOHIDRequestAccess(kIOHIDRequestTypeListenEvent)
        }
        // Enquanto não conecta (por exemplo, esperando a permissão), procura de novo a cada 3 segundos.
        Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.procura() }
        }

        relogio = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in await self?.atualizaBateria() }
        }
        NotificationCenter.default.addObserver(forName: Notification.Name("M913.reabriu"), object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.mostrarSempre = true }
        }
        // App de barra do topo sem janela: o macOS não pode encerrar por estar "ocioso".
        ProcessInfo.processInfo.disableAutomaticTermination("Acompanha a bateria do mouse")
        ProcessInfo.processInfo.disableSuddenTermination()
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    // MARK: Conexão

    func procura() {
        guard receptor == nil || cabo == nil, let todos = IOHIDManagerCopyDevices(gerente) as? Set<IOHIDDevice> else { return }
        for d in todos { chegou(d) }
    }

    func abreAjustesDePermissao() {
        _ = IOHIDRequestAccess(kIOHIDRequestTypeListenEvent)
        if let u = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent") {
            NSWorkspace.shared.open(u)
        }
    }

    private func propriedade(_ d: IOHIDDevice, _ chave: String) -> Int {
        IOHIDDeviceGetProperty(d, chave as CFString) as? Int ?? 0
    }

    private func chegou(_ d: IOHIDDevice) {
        let produto = propriedade(d, kIOHIDProductIDKey)
        depura("chegou \(String(format: "%04x", produto)) feature=\(propriedade(d, kIOHIDMaxFeatureReportSizeKey))")
        guard propriedade(d, kIOHIDMaxFeatureReportSizeKey) >= 17 else { return }
        if produto == M913.produtoCabo, cabo == nil, abre(d) {
            cabo = d
            marcaLigado()
        } else if produto == M913.produtoSemFio, receptor == nil, abre(d) {
            receptor = d
        } else {
            return
        }
        atualizaConexao()
        Task {
            await atualizaBateria()
            await leConfig()
            // O outro canal pode chegar logo depois e ser o único que atende a leitura.
            if config == nil {
                try? await Task.sleep(for: .seconds(2))
                await leConfig()
            }
        }
    }

    private func atualizaConexao() {
        conexao = cabo != nil ? .cabo : (receptor != nil ? .semFio : .desconectado)
    }

    private func abre(_ d: IOHIDDevice) -> Bool {
        let r = IOHIDDeviceOpen(d, IOOptionBits(kIOHIDOptionsTypeNone))
        depura("abrir: \(String(format: "0x%08x", r)) acesso=\(IOHIDCheckAccess(kIOHIDRequestTypeListenEvent).rawValue)")
        guard r == kIOReturnSuccess else {
            semPermissao = true
            return false
        }
        semPermissao = false
        let eu = Unmanaged.passUnretained(self).toOpaque()
        IOHIDDeviceRegisterInputReportCallback(d, buffer(for: d), 64, { ctx, _, _, _, id, relatorio, tamanho in
            let m = Unmanaged<Mouse>.fromOpaque(ctx!).takeUnretainedValue()
            let bytes = Array(UnsafeBufferPointer(start: relatorio, count: tamanho))
            MainActor.assumeIsolated { m.recebeu(id: UInt8(truncatingIfNeeded: id), bytes) }
        }, eu)
        IOHIDDeviceScheduleWithRunLoop(d, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
        return true
    }

    private func buffer(for d: IOHIDDevice) -> UnsafeMutablePointer<UInt8> {
        propriedade(d, kIOHIDProductIDKey) == M913.produtoCabo ? bufferCabo : buffer
    }

    private func saiu(_ d: IOHIDDevice) {
        if let c = cabo, CFEqual(c, d) { cabo = nil }
        else if let r = receptor, CFEqual(r, d) { receptor = nil }
        else { return }
        atualizaConexao()
        for e in esperas { e.continua.resume(returning: nil) }
        esperas.removeAll()
        if conexao == .desconectado { ligado = false }
        informaSistema()
        if conexao != .desconectado { Task { await atualizaBateria() } }
    }

    // MARK: Pedido e resposta

    private func recebeu(id: UInt8, _ b: [UInt8]) {
        depura("recebeu \(id): \(hex(b))")
        guard b.count >= 17, b[0] == M913.relatorioResposta else { return }
        let sub = b[1]
        let endereco = (Int(b[3]) << 8) | Int(b[4])
        if let i = esperas.firstIndex(where: { $0.sub == sub && ($0.endereco == nil || $0.endereco == endereco) }) {
            let e = esperas.remove(at: i)
            e.continua.resume(returning: b)
        } else if sub == M913.subConfirma {
            registraBateria(b)
        }
    }

    private func envia(_ p: Pacote, por d: IOHIDDevice) -> Bool {
        depura("envia \(hex(p))")
        let r = p.withUnsafeBufferPointer {
            IOHIDDeviceSetReport(d, kIOHIDReportTypeFeature, CFIndex(M913.relatorioPedido), $0.baseAddress!, p.count)
        }
        return r == kIOReturnSuccess
    }

    /// Manda o pacote e espera a resposta do mouse. Mouse parado demora a responder,
    /// então tenta algumas vezes.
    private func pede(_ p: Pacote, tentativas: Int = 4, espera: Double = 0.35, bateria: Bool = false) async -> [UInt8]? {
        let sub = p[1]
        let endereco = sub == M913.subConfirma ? nil : (Int(p[3]) << 8) | Int(p[4])
        for _ in 0..<tentativas {
            guard let d = bateria ? canalBateria : canal else { return nil }
            let id = UUID()
            let resposta: [UInt8]? = await withCheckedContinuation { c in
                esperas.append((id, sub, endereco, c))
                if !envia(p, por: d) {
                    if let i = esperas.firstIndex(where: { $0.id == id }) { esperas.remove(at: i).continua.resume(returning: nil) }
                    return
                }
                Task { @MainActor in
                    try? await Task.sleep(for: .seconds(espera))
                    if let i = self.esperas.firstIndex(where: { $0.id == id }) {
                        self.esperas.remove(at: i).continua.resume(returning: nil)
                    }
                }
            }
            if let r = resposta { return r }
        }
        return nil
    }

    // MARK: Bateria

    func atualizaBateria() async {
        guard canal != nil, !gravando else { return }
        if let r = await pede(Monta.bateria, tentativas: 3, bateria: true) {
            registraBateria(r)
            marcaLigado()
        } else if conexao != .cabo {
            // Três minutos seguidos sem resposta: mouse desligado.
            falhas += 1
            if falhas >= 3 { ligado = false; informaSistema() }
        }
    }

    private func sinalDeVida() {
        guard Date().timeIntervalSince(ultimoSinal) > 5 else { return }
        ultimoSinal = Date()
        let estavaDesligado = !ligado
        marcaLigado()
        if estavaDesligado {
            Task {
                await atualizaBateria()
                if config == nil { await leConfig() }
            }
        }
    }

    private func marcaLigado() {
        falhas = 0
        if !ligado { ligado = true; informaSistema() }
    }

    private func registraBateria(_ r: [UInt8]) {
        // Resposta: 09 04 00 00 00 02 NN ...  NN = nível de 0 a 10.
        guard r.count > 6, r[1] == M913.subConfirma, r[2] == 0x00 else { return }
        let bruto = Int(r[6])
        let pct = bruto <= 10 ? bruto * 10 : min(bruto, 100)
        let anterior = bateria
        bateria = pct
        atualizadoEm = Date()
        defer { informaSistema() }

        // O byte seguinte ao nível diz se está carregando (1) ou não (0).
        marcaCarregando(r.count > 7 && r[7] == 0x01)

        if pct <= 20 && !carregando && !avisouBaixa {
            avisouBaixa = true
            notifica("Bateria do mouse em \(pct)%", "Ligue o Red Dragon no carregador.")
        }
        if pct > 30 { avisouBaixa = false }
    }

    private func informaSistema() {
        if ligado || conexao == .cabo, let b = bateria {
            sistema.publica(nivel: b, carregando: carregando, cabo: conexao == .cabo)
        } else {
            sistema.remove()
        }
    }

    private func marcaCarregando(_ sim: Bool) {
        guard sim != carregando else { return }
        carregando = sim
        informaSistema()
        if sim {
            notifica("Mouse carregando", bateria.map { "Bateria em \($0)%." } ?? "Carregamento começou.")
        } else if let b = bateria, b >= 100 {
            notifica("Mouse carregado", "Bateria em 100%.")
        }
    }

    private func notifica(_ titulo: String, _ texto: String) {
        let c = UNMutableNotificationContent()
        c.title = titulo
        c.body = texto
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: UUID().uuidString, content: c, trigger: nil))
    }

    // MARK: Leitura

    func leConfig() async {
        guard canal != nil, !lendo, !gravando else { return }
        lendo = true
        defer { lendo = false }
        var memoria = [UInt8](repeating: 0, count: 160)
        for bloco in 0..<16 {
            guard let r = await pede(Monta.le(bloco * 10)) else {
                aviso = "O mouse não respondeu. Mexa nele um pouco e tente de novo."
                return
            }
            for j in 0..<10 where 6 + j < r.count { memoria[bloco * 10 + j] = r[6 + j] }
        }
        var teclados: [Int: [UInt8]] = [:]
        for i in 0..<16 where memoria[0x60 + i * 4] == 0x05 {
            let e = Botoes.enderecoTeclado[i]
            if let a = await pede(Monta.le(e), tentativas: 3), let b = await pede(Monta.le(e + 10), tentativas: 3) {
                teclados[i] = Array(a[6..<16]) + Array(b[6..<16])
            }
        }
        Copia.guarda(memoria: memoria, teclados: teclados)
        let c = Decodifica.config(memoria: memoria, teclados: teclados)
        config = c
        rascunho = c
        aviso = nil
    }

    // MARK: Gravação

    var botoesAlterados: Set<Int> {
        guard let c = config else { return [] }
        return Set((0..<16).filter { c.acoes[$0] != rascunho.acoes[$0] })
    }

    var alteracoes: [String] {
        guard let c = config else { return [] }
        var l: [String] = []
        let b = botoesAlterados.count
        if b > 0 { l.append(b == 1 ? "1 botão" : "\(b) botões") }
        if c.dpi != rascunho.dpi || c.estagios != rascunho.estagios { l.append("DPI") }
        if c.luz != rascunho.luz || c.cor != rascunho.cor || c.brilho != rascunho.brilho || c.velocidade != rascunho.velocidade { l.append("luz") }
        if c.taxa != rascunho.taxa { l.append("taxa de resposta") }
        return l
    }

    func desfaz() { if let c = config { rascunho = c } }

    func voltaFabrica() {
        var f = rascunho
        f.taxa = 1000
        f.dpi = [500, 1000, 2000, 3000, 6000]
        f.estagios = 5
        f.luz = .arcoIris
        f.brilho = 255
        f.velocidade = 3
        for i in 0..<16 { f.acoes[i] = Botoes.fabrica[i] ?? .direta("none") }
        rascunho = f
    }

    func grava() async {
        guard let c = config, canal != nil, !gravando else { return }
        gravando = true
        defer { gravando = false }
        var pacotes: [Pacote] = []
        let alterados = botoesAlterados
        if !alterados.isEmpty { pacotes += Monta.botoes(rascunho, alterados: alterados) }
        if c.dpi != rascunho.dpi || c.estagios != rascunho.estagios { pacotes += Monta.dpi(rascunho) }
        if c.luz != rascunho.luz || c.cor != rascunho.cor || c.brilho != rascunho.brilho || c.velocidade != rascunho.velocidade {
            pacotes += Monta.luz(rascunho)
        }
        if c.taxa != rascunho.taxa { pacotes.append(Monta.taxa(rascunho.taxa)) }
        guard !pacotes.isEmpty else { return }

        for p in pacotes {
            guard await pede(p, tentativas: 6) != nil else {
                aviso = "O mouse parou de responder no meio da gravação. Mexa nele e grave de novo."
                return
            }
        }
        _ = await pede(Monta.confirma, tentativas: 2)
        try? await Task.sleep(for: .milliseconds(150))
        _ = await pede(Monta.confirma, tentativas: 2)
        try? await Task.sleep(for: .milliseconds(150))

        gravando = false
        await leConfig()
        if let novo = config, novo.acoes != rascunho.acoes && !alterados.isEmpty {
            aviso = "Gravei, mas a leitura de volta veio diferente em algum botão. Confira a lista."
        }
    }
}

/// Guarda uma cópia da memória do mouse antes de qualquer mudança.
enum Copia {
    static var pasta: URL {
        let u = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("M913", isDirectory: true)
        try? FileManager.default.createDirectory(at: u, withIntermediateDirectories: true)
        return u
    }

    static func guarda(memoria: [UInt8], teclados: [Int: [UInt8]]) {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        let arquivo = pasta.appendingPathComponent("copia-\(f.string(from: Date())).json")
        guard !FileManager.default.fileExists(atPath: arquivo.path) else { return }
        let dados: [String: Any] = [
            "memoria": hex(memoria),
            "teclados": Dictionary(uniqueKeysWithValues: teclados.map { (String($0.key), hex($0.value)) }),
        ]
        if let j = try? JSONSerialization.data(withJSONObject: dados, options: [.prettyPrinted, .sortedKeys]) {
            try? j.write(to: arquivo)
        }
    }
}
