import SwiftUI

enum Secao: String, CaseIterable, Identifiable {
    case botoes = "Botões", dpi = "DPI", luz = "Luz", desempenho = "Desempenho"
    var id: String { rawValue }
    var simbolo: String {
        switch self {
        case .botoes: return "square.grid.3x3"
        case .dpi: return "scope"
        case .luz: return "lightbulb"
        case .desempenho: return "speedometer"
        }
    }
}

struct JanelaConfig: View {
    @EnvironmentObject var mouse: Mouse
    @State private var secao: Secao = .botoes

    var body: some View {
        NavigationSplitView {
            List(Secao.allCases, selection: $secao) { s in
                Label(s.rawValue, systemImage: s.simbolo).tag(s)
            }
            .navigationSplitViewColumnWidth(min: 170, ideal: 190)
            .safeAreaInset(edge: .bottom) {
                if mouse.conexao != .desconectado {
                    PainelBateria().padding(14)
                }
            }
        } detail: {
            Group {
                if mouse.semPermissao {
                    AvisoPermissao().frame(maxWidth: 360).frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if mouse.conexao == .desconectado {
                    ContentUnavailableView("Receptor não encontrado",
                        systemImage: "computermouse",
                        description: Text("Ligue o receptor USB do Red Dragon no Mac e confira se o mouse está ligado."))
                } else if mouse.config == nil {
                    VStack(spacing: 12) {
                        if mouse.lendo {
                            ProgressView()
                            Text("Lendo a configuração do mouse…").foregroundStyle(.secondary)
                            Text("Mexa o mouse se demorar: parado, ele responde devagar.")
                                .font(.caption).foregroundStyle(.tertiary)
                        } else {
                            Text(mouse.aviso ?? "Não deu para ler a configuração.").foregroundStyle(.secondary)
                            Button("Tentar de novo") { Task { await mouse.leConfig() } }
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    switch secao {
                    case .botoes: TelaBotoes()
                    case .dpi: TelaDPI()
                    case .luz: TelaLuz()
                    case .desempenho: TelaDesempenho()
                    }
                }
            }
            .navigationTitle(secao.rawValue)
            .safeAreaInset(edge: .bottom) {
                if mouse.config != nil { BarraGravar() }
            }
        }
    }
}

struct BarraGravar: View {
    @EnvironmentObject var mouse: Mouse

    @State private var confirmaFabrica = false

    var body: some View {
        let pendente = !mouse.alteracoes.isEmpty
        HStack(spacing: 12) {
            if mouse.gravando || (mouse.aguardando && mouse.aviso == nil) {
                ProgressView().controlSize(.small)
                Text("Gravando no mouse…").foregroundStyle(.secondary)
            } else if let a = mouse.aviso {
                Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                Text(a).foregroundStyle(.secondary).lineLimit(2)
                if pendente {
                    Button("Tentar de novo") { Task { await mouse.grava() } }
                }
            } else {
                Image(systemName: "checkmark.circle").foregroundStyle(.secondary)
                Text("Gravado no mouse. As mudanças são gravadas sozinhas.").foregroundStyle(.secondary)
            }
            Spacer()
            Menu {
                Button("Ler de novo do mouse") { Task { await mouse.leConfig() } }
                Button("Voltar ao padrão de fábrica…") { confirmaFabrica = true }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .disabled(mouse.gravando)
            Button("Desfazer") { mouse.desfaz() }
                .keyboardShortcut("z", modifiers: .command)
                .disabled(mouse.anterior == nil || mouse.gravando)
                .help("Volta o mouse para como estava antes da última mudança.")
        }
        .confirmationDialog("Voltar o mouse ao padrão de fábrica?", isPresented: $confirmaFabrica) {
            Button("Voltar ao padrão", role: .destructive) { mouse.voltaFabrica() }
        } message: {
            Text("Botões, DPI, luz e taxa de resposta voltam ao original e são gravados no mouse. Dá para desfazer em seguida.")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.bar)
        .overlay(alignment: .top) { Divider() }
    }
}

// MARK: - Botões

/// Liga o ⌘, ⌥, ⌃ e ⇧ do teclado às teclas que vêm do mouse.
struct OpcaoModificadores: View {
    @EnvironmentObject var junta: JuntaModificadores

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle(isOn: $junta.ligado) {
                Text("Juntar com o teclado").font(.headline)
            }
            .toggleStyle(.switch)
            .controlSize(.small)
            Text("Segure ⌘, ⌥, ⌃ ou ⇧ no teclado e aperte uma lateral: sai a combinação, como ⌘F1. Sem segurar nada, sai só a tecla.")
                .font(.caption).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if junta.ligado && !junta.temPermissao {
                VStack(alignment: .leading, spacing: 6) {
                    Label("Falta liberar o app em Acessibilidade.", systemImage: "lock.fill")
                        .font(.callout)
                        .foregroundStyle(.orange)
                    Button("Abrir Ajustes de Acessibilidade") { junta.pedePermissao() }
                        .controlSize(.small)
                }
                .padding(.top, 2)
            }
        }
    }
}

struct TelaBotoes: View {
    @EnvironmentObject var mouse: Mouse
    @State private var escolhido = 0

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Laterais").font(.headline)
                        Text("Na mesma posição dos 12 botões do lado do mouse.")
                            .font(.caption).foregroundStyle(.secondary)
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                            ForEach(Array(Botoes.laterais.enumerated()), id: \.element) { n, i in
                                Tecla(numero: "\(n + 1)", indice: i, escolhido: $escolhido)
                            }
                        }
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Principais").font(.headline)
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 2), spacing: 8) {
                            ForEach(Botoes.principais, id: \.self) { i in
                                Tecla(numero: nil, indice: i, escolhido: $escolhido)
                            }
                        }
                    }
                    OpcaoModificadores()
                }
                .padding(20)
            }
            .frame(minWidth: 300, idealWidth: 340, maxWidth: 380)

            Divider()

            EditorBotao(indice: escolhido)
                .id(escolhido)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }
}

struct Tecla: View {
    @EnvironmentObject var mouse: Mouse
    let numero: String?
    let indice: Int
    @Binding var escolhido: Int

    var body: some View {
        let acao = mouse.rascunho.acoes[indice]
        let mudou = mouse.botoesAlterados.contains(indice)
        let ativo = escolhido == indice
        Button { escolhido = indice } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(numero ?? Botoes.nomes[indice] ?? "")
                        .font(numero == nil ? .caption.weight(.medium) : .title3.weight(.semibold).monospacedDigit())
                        .foregroundStyle(ativo ? Color.white : Color.primary)
                    Spacer()
                    if mudou { Circle().fill(.orange).frame(width: 6, height: 6) }
                }
                Text(acao.nome)
                    .font(.caption)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .foregroundStyle(ativo ? Color.white.opacity(0.85) : Color.secondary)
                    .frame(maxWidth: .infinity, minHeight: 28, alignment: .topLeading)
            }
            .padding(10)
            .background(ativo ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(.quaternary.opacity(0.6)),
                        in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(Pressionavel())
    }
}

struct Pressionavel: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct EditorBotao: View {
    @EnvironmentObject var mouse: Mouse
    let indice: Int
    @State private var gravandoAtalho = false

    private var acao: Binding<Acao> {
        Binding(get: { mouse.rascunho.acoes[indice] }, set: { mouse.rascunho.acoes[indice] = $0 })
    }

    var body: some View {
        Form {
            Section {
                LabeledContent("Faz agora") {
                    Label(acao.wrappedValue.nome, systemImage: acao.wrappedValue.simbolo)
                }
                if let original = mouse.config?.acoes[indice], original != acao.wrappedValue {
                    LabeledContent("Gravado no mouse") {
                        Text(original.nome).foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text(Botoes.nomes[indice] ?? "Botão").font(.title3.weight(.semibold))
            }

            Section("Atalho de teclado") {
                GravadorAtalho(acao: acao, gravando: $gravandoAtalho)
                Text("O mouse aperta e solta o atalho uma vez a cada clique. Segurar o botão não repete a tecla.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section("Tiro rápido") {
                let tiro: (Int, Int)? = { if case .tiro(let ms, let v) = acao.wrappedValue { return (ms, v) }; return nil }()
                Toggle("Usar tiro rápido", isOn: Binding(
                    get: { tiro != nil },
                    set: { acao.wrappedValue = $0 ? .tiro(intervalo: 58, vezes: 3) : (Botoes.fabrica[indice] ?? .direta("left")) }))
                if let (ms, vezes) = tiro {
                    Stepper(value: Binding(get: { ms }, set: { acao.wrappedValue = .tiro(intervalo: $0, vezes: vezes) }), in: 3...255, step: 5) {
                        LabeledContent("Intervalo", value: "\(ms) ms")
                    }
                    Picker("Cliques por toque", selection: Binding(get: { vezes }, set: { acao.wrappedValue = .tiro(intervalo: ms, vezes: $0) })) {
                        Text("Contínuo").tag(0)
                        Text("1").tag(1)
                        Text("2").tag(2)
                        Text("3").tag(3)
                    }
                    .pickerStyle(.segmented)
                }
            }

            ForEach(["Mouse", "DPI"], id: \.self) { grupo in
                Section(grupo) {
                    ForEach(Catalogo.diretas.filter { $0.grupo == grupo }) { o in
                        LinhaOpcao(opcao: o, marcada: acao.wrappedValue == .direta(o.id)) { acao.wrappedValue = .direta(o.id) }
                    }
                }
            }
            ForEach(["Mídia", "Navegador"], id: \.self) { grupo in
                Section(grupo) {
                    ForEach(Catalogo.midia.filter { $0.grupo == grupo }) { o in
                        LinhaOpcao(opcao: o, marcada: acao.wrappedValue == .midia(o.id)) { acao.wrappedValue = .midia(o.id) }
                    }
                }
            }

            if let f = Botoes.fabrica[indice] {
                Section {
                    Button("Voltar este botão ao padrão (\(f.nome))") { acao.wrappedValue = f }
                }
            }
        }
        .formStyle(.grouped)
    }
}

struct LinhaOpcao: View {
    let opcao: OpcaoDireta
    let marcada: Bool
    let escolhe: () -> Void

    var body: some View {
        Button(action: escolhe) {
            HStack {
                Label(opcao.nome, systemImage: opcao.simbolo)
                Spacer()
                if marcada { Image(systemName: "checkmark").foregroundStyle(Color.accentColor) }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct GravadorAtalho: View {
    @Binding var acao: Acao
    @Binding var gravando: Bool
    @State private var monitor: Any?

    var body: some View {
        HStack {
            if gravando {
                Text("Aperte o atalho agora…").foregroundStyle(Color.accentColor)
            } else if case .teclado = acao {
                Text(acao.nome).font(.body.monospaced())
            } else {
                Text("Nenhum").foregroundStyle(.secondary)
            }
            Spacer()
            Button(gravando ? "Cancelar" : "Gravar atalho") { gravando ? para() : comeca() }
        }
        .onDisappear(perform: para)
    }

    private func comeca() {
        gravando = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { e in
            guard let hid = Teclas.doMac[e.keyCode] else { return nil }
            var mods: UInt8 = 0
            if e.modifierFlags.contains(.control) { mods |= Teclas.ctrl }
            if e.modifierFlags.contains(.shift) { mods |= Teclas.shift }
            if e.modifierFlags.contains(.option) { mods |= Teclas.opt }
            if e.modifierFlags.contains(.command) { mods |= Teclas.cmd }
            acao = .teclado(mods: mods, teclas: [hid])
            para()
            return nil
        }
    }

    private func para() {
        if let m = monitor { NSEvent.removeMonitor(m) }
        monitor = nil
        gravando = false
    }
}

// MARK: - DPI

struct TelaDPI: View {
    @EnvironmentObject var mouse: Mouse

    var body: some View {
        Form {
            Section {
                Picker("Quantos níveis usar", selection: $mouse.rascunho.estagios) {
                    ForEach(1...5, id: \.self) { Text("\($0)").tag($0) }
                }
                .pickerStyle(.segmented)
                if mouse.rascunho.estagios == 1 {
                    Label("Com 1 nível, os botões de DPI do mouse não mudam nada. Escolha 2 ou mais.", systemImage: "exclamationmark.triangle.fill")
                        .font(.callout)
                        .foregroundStyle(.orange)
                }
            } footer: {
                Text("Os dois botões atrás da rodinha sobem e descem de nível, só entre os níveis usados. As 4 luzinhas ao lado deles mostram o nível: nenhuma acesa é o 1, as quatro acesas é o 5.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section("Níveis") {
                ForEach(0..<5, id: \.self) { i in
                    let ativo = i < mouse.rascunho.estagios
                    HStack(spacing: 12) {
                        Text("\(i + 1)")
                            .font(.headline.monospacedDigit())
                            .frame(width: 22, height: 22)
                            .background(ativo ? Color.accentColor.opacity(0.15) : Color.secondary.opacity(0.1), in: Circle())
                        Slider(value: Binding(
                            get: { Double(TabelaDPI.valores.firstIndex(of: mouse.rascunho.dpi[i]) ?? 0) },
                            set: { mouse.rascunho.dpi[i] = TabelaDPI.valores[Int($0.rounded())] }),
                               in: 0...Double(TabelaDPI.valores.count - 1), step: 1)
                        Text("\(mouse.rascunho.dpi[i])")
                            .font(.body.monospacedDigit())
                            .frame(width: 60, alignment: .trailing)
                    }
                    .opacity(ativo ? 1 : 0.4)
                }
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Luz

struct TelaLuz: View {
    @EnvironmentObject var mouse: Mouse

    var body: some View {
        Form {
            Section {
                Picker("Efeito", selection: $mouse.rascunho.luz) {
                    ForEach(ModoLuz.allCases) { Text($0.nome).tag($0) }
                }
                .pickerStyle(.segmented)
            } footer: {
                Text("A luz é a do logo do dragão. Desligada, a bateria dura mais.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            if mouse.rascunho.luz == .fixa || mouse.rascunho.luz == .respiracao {
                Section {
                    SeletorCor(cor: $mouse.rascunho.cor)
                    if mouse.rascunho.luz == .fixa {
                        LabeledContent("Brilho") {
                            Slider(value: Binding(get: { Double(mouse.rascunho.brilho) }, set: { mouse.rascunho.brilho = Int($0) }), in: 0...255)
                                .frame(maxWidth: 260)
                        }
                    }
                }
            }

            if mouse.rascunho.luz == .respiracao || mouse.rascunho.luz == .arcoIris {
                Section {
                    Picker("Velocidade", selection: $mouse.rascunho.velocidade) {
                        ForEach(1...5, id: \.self) { Text("\($0)").tag($0) }
                    }
                    .pickerStyle(.segmented)
                } footer: {
                    Text("1 é o mais rápido, 5 o mais lento.").font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Desempenho

struct TelaDesempenho: View {
    @EnvironmentObject var mouse: Mouse

    var body: some View {
        Form {
            Section {
                Picker("Taxa de resposta", selection: $mouse.rascunho.taxa) {
                    ForEach([125, 250, 500, 1000], id: \.self) { Text("\($0) Hz").tag($0) }
                }
                .pickerStyle(.segmented)
            } footer: {
                Text("1000 Hz responde mais rápido nos jogos. 125 Hz gasta menos bateria.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("Cópia de segurança") {
                LabeledContent("Pasta") {
                    Button("Mostrar no Finder") { NSWorkspace.shared.activateFileViewerSelecting([Copia.pasta]) }
                }
                Text("Ao ler o mouse, o app guarda uma cópia por dia da configuração, antes de qualquer mudança.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Seletor de cor

/// Seletor de cor da luz do logo: cores prontas e, se quiser, uma personalizada (matiz e intensidade).
struct SeletorCor: View {
    @Binding var cor: CorRGB
    @State private var editando = false
    @State private var matiz: Double = 0
    @State private var saturacao: Double = 1

    /// Valores pensados para o LED: o laranja e o amarelo levam menos verde, senão puxam para o verde-limão.
    static let prontas: [(nome: String, cor: CorRGB)] = [
        ("Vermelho", CorRGB(r: 255, g: 0, b: 0)),
        ("Laranja", CorRGB(r: 255, g: 64, b: 0)),
        ("Amarelo", CorRGB(r: 255, g: 180, b: 0)),
        ("Verde", CorRGB(r: 0, g: 255, b: 0)),
        ("Ciano", CorRGB(r: 0, g: 255, b: 255)),
        ("Azul", CorRGB(r: 0, g: 0, b: 255)),
        ("Roxo", CorRGB(r: 128, g: 0, b: 255)),
        ("Rosa", CorRGB(r: 255, g: 0, b: 160)),
        ("Branco", CorRGB(r: 255, g: 255, b: 255)),
    ]

    private var ehPronta: Bool { Self.prontas.contains { $0.cor == cor } }
    private var personalizadaAtiva: Bool { editando || !ehPronta }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center) {
                Text("Cor")
                Spacer(minLength: 16)
                HStack(spacing: 8) {
                    ForEach(Self.prontas, id: \.nome) { p in
                        Amostra(cor: p.cor.color, selecionada: p.cor == cor && !editando) {
                            cor = p.cor
                            editando = false
                        }
                        .help(p.nome)
                        .accessibilityLabel(p.nome)
                    }
                    Divider().frame(height: 18).padding(.horizontal, 2)
                    Amostra(cor: ehPronta ? nil : cor.color, selecionada: personalizadaAtiva) {
                        sincroniza()
                        editando.toggle()
                    }
                    .help("Personalizada")
                    .accessibilityLabel("Cor personalizada")
                }
            }

            if personalizadaAtiva {
                VStack(alignment: .leading, spacing: 12) {
                    LinhaBarra(titulo: "Tom", valor: $matiz, cores: (0...12).map { Color(hue: Double($0) / 12, saturation: 1, brightness: 1) },
                               corPino: Color(hue: matiz, saturation: 1, brightness: 1))
                    LinhaBarra(titulo: "Intensidade", valor: $saturacao,
                               cores: [.white, Color(hue: matiz, saturation: 1, brightness: 1)],
                               corPino: cor.color)
                    HStack {
                        Text("Código").foregroundStyle(.secondary)
                        Spacer()
                        CampoHex(cor: $cor)
                    }
                }
                .padding(.leading, 2)
                .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.18), value: personalizadaAtiva)
        .onAppear(perform: sincroniza)
        .onChange(of: matiz) { aplica() }
        .onChange(of: saturacao) { aplica() }
    }

    /// Lê o tom e a intensidade da cor atual. No branco (sem tom) mantém o tom que já estava.
    private func sincroniza() {
        let n = NSColor(srgbRed: CGFloat(cor.r) / 255, green: CGFloat(cor.g) / 255, blue: CGFloat(cor.b) / 255, alpha: 1)
        if n.saturationComponent > 0.01 { matiz = n.hueComponent }
        saturacao = n.saturationComponent
    }

    private func aplica() {
        let n = NSColor(hue: matiz, saturation: saturacao, brightness: 1, alpha: 1).usingColorSpace(.sRGB) ?? .red
        let nova = CorRGB(r: UInt8((n.redComponent * 255).rounded()), g: UInt8((n.greenComponent * 255).rounded()),
                          b: UInt8((n.blueComponent * 255).rounded()))
        if nova != cor { cor = nova }
    }
}

/// Bolinha de cor clicável. Sem cor, mostra o arco-íris da opção personalizada.
private struct Amostra: View {
    let cor: Color?
    let selecionada: Bool
    let acao: () -> Void

    var body: some View {
        Button(action: acao) {
            ZStack {
                if let cor {
                    Circle().fill(cor)
                } else {
                    Circle().fill(AngularGradient(colors: (0...6).map { Color(hue: Double($0) / 6, saturation: 0.85, brightness: 1) }, center: .center))
                }
                Circle().strokeBorder(.primary.opacity(0.18), lineWidth: 0.5)
            }
            .frame(width: 20, height: 20)
            .padding(3)
            .overlay(Circle().strokeBorder(selecionada ? Color.accentColor : .clear, lineWidth: 2))
            .contentShape(Circle())
        }
        .buttonStyle(Pressionavel())
        .accessibilityAddTraits(selecionada ? .isSelected : [])
    }
}

/// Barra com degradê e um pino arrastável, de 0 a 1.
private struct LinhaBarra: View {
    let titulo: String
    @Binding var valor: Double
    let cores: [Color]
    let corPino: Color

    var body: some View {
        HStack(spacing: 12) {
            Text(titulo).foregroundStyle(.secondary).frame(width: 84, alignment: .leading)
            GeometryReader { g in
                let largura = g.size.width
                ZStack(alignment: .leading) {
                    Capsule().fill(LinearGradient(colors: cores, startPoint: .leading, endPoint: .trailing))
                        .overlay(Capsule().strokeBorder(.primary.opacity(0.15), lineWidth: 0.5))
                        .frame(height: 10)
                    Circle()
                        .fill(corPino)
                        .overlay(Circle().strokeBorder(.white, lineWidth: 2.5))
                        .shadow(color: .black.opacity(0.35), radius: 2, y: 1)
                        .frame(width: 18, height: 18)
                        .offset(x: (largura - 18) * valor)
                }
                .frame(maxHeight: .infinity)
                .contentShape(Rectangle())
                .gesture(DragGesture(minimumDistance: 0).onChanged { v in
                    valor = min(1, max(0, (v.location.x - 9) / max(1, largura - 18)))
                })
            }
            .frame(height: 20)
            .frame(maxWidth: 320)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(titulo)
        .accessibilityValue("\(Int(valor * 100))%")
        .accessibilityAdjustableAction { d in
            valor = min(1, max(0, valor + (d == .increment ? 0.05 : -0.05)))
        }
    }
}

/// Campo do código da cor (#RRGGBB). Só aplica quando o código é válido.
private struct CampoHex: View {
    @Binding var cor: CorRGB
    @State private var texto = ""
    @FocusState private var focado: Bool

    var body: some View {
        TextField("", text: $texto)
            .textFieldStyle(.roundedBorder)
            .font(.body.monospaced())
            .frame(width: 92)
            .focused($focado)
            .onAppear { texto = cor.hex }
            .onChange(of: cor) { if !focado { texto = cor.hex } }
            .onSubmit(aplica)
            .onChange(of: focado) { if !focado { aplica() } }
            .accessibilityLabel("Código da cor")
    }

    private func aplica() {
        let limpo = texto.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: "#", with: "")
        guard limpo.count == 6, let v = UInt32(limpo, radix: 16) else { texto = cor.hex; return }
        cor = CorRGB(r: UInt8(v >> 16 & 0xff), g: UInt8(v >> 8 & 0xff), b: UInt8(v & 0xff))
        texto = cor.hex
    }
}

extension CorRGB {
    var color: Color { Color(.sRGB, red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255) }
    var hex: String { String(format: "#%02X%02X%02X", r, g, b) }
}
