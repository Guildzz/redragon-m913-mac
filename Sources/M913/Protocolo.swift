import Foundation

// Protocolo do Redragon M913 Impact Elite (receptor Areson 25a7:fa07, cabo 25a7:fa08).
// Portado do m913-ctl (github.com/Qehbr/m913-ctl) e do configurador web
// (github.com/Olek97/Redragon_M913_Web_Configurator), ambos GPL-3.0.
//
// Pacote de 17 bytes, relatório 8 (feature):
//   [0] 0x08  [1] subcomando (0x07 grava, 0x08 lê, 0x04 confirma/bateria)
//   [3] endereço alto  [4] endereço baixo  [5] tamanho  [6..13] dados
//   [16] conferência = (0x55 - soma dos bytes 0..15) & 0xff
// A resposta vem pelo relatório 9 (entrada), com o mesmo formato.
// No Mac o pacote vai inteiro, com o 0x08 na frente.

typealias Pacote = [UInt8]

enum M913 {
    static let fabricante = 0x25a7
    static let produtoSemFio = 0xfa07
    static let produtoCabo = 0xfa08
    static let relatorioPedido: UInt8 = 0x08
    static let relatorioResposta: UInt8 = 0x09

    static let subGrava: UInt8 = 0x07
    static let subLe: UInt8 = 0x08
    static let subConfirma: UInt8 = 0x04
}

func conferencia(_ valores: [Int]) -> UInt8 {
    UInt8(truncatingIfNeeded: 0x55 - valores.reduce(0, +))
}

func fechaPacote(_ p: inout Pacote) {
    p[16] = conferencia(p[0..<16].map(Int.init))
}

func novoPacote(sub: UInt8, endereco: Int = 0, tamanho: Int = 0, dados: [UInt8] = []) -> Pacote {
    var p = Pacote(repeating: 0, count: 17)
    p[0] = M913.relatorioPedido
    p[1] = sub
    p[3] = UInt8((endereco >> 8) & 0xff)
    p[4] = UInt8(endereco & 0xff)
    p[5] = UInt8(tamanho)
    for (i, b) in dados.enumerated() where 6 + i < 16 { p[6 + i] = b }
    fechaPacote(&p)
    return p
}

func hex(_ b: [UInt8]) -> String { b.map { String(format: "%02x", $0) }.joined(separator: " ") }

// MARK: - Ações dos botões

struct OpcaoDireta: Identifiable, Hashable {
    let id: String
    let nome: String
    let grupo: String
    let bytes: [UInt8]
    let simbolo: String
}

enum Catalogo {
    static let diretas: [OpcaoDireta] = [
        .init(id: "left", nome: "Clique esquerdo", grupo: "Mouse", bytes: [0x01, 0x01, 0x00, 0x53], simbolo: "computermouse"),
        .init(id: "right", nome: "Clique direito", grupo: "Mouse", bytes: [0x01, 0x02, 0x00, 0x52], simbolo: "computermouse"),
        .init(id: "middle", nome: "Clique do meio", grupo: "Mouse", bytes: [0x01, 0x04, 0x00, 0x50], simbolo: "computermouse"),
        .init(id: "back", nome: "Voltar", grupo: "Mouse", bytes: [0x01, 0x08, 0x00, 0x4c], simbolo: "chevron.left"),
        .init(id: "forward", nome: "Avançar", grupo: "Mouse", bytes: [0x01, 0x10, 0x00, 0x44], simbolo: "chevron.right"),
        .init(id: "double_click", nome: "Clique duplo", grupo: "Mouse", bytes: [0x01, 0x20, 0x00, 0x34], simbolo: "cursorarrow.click.2"),
        .init(id: "three_click", nome: "Clique triplo", grupo: "Mouse", bytes: [0x04, 0x32, 0x03, 0x1c], simbolo: "cursorarrow.click.2"),
        .init(id: "scroll_up", nome: "Rolar para cima", grupo: "Mouse", bytes: [0x01, 0x00, 0x01, 0x53], simbolo: "arrow.up"),
        .init(id: "scroll_down", nome: "Rolar para baixo", grupo: "Mouse", bytes: [0x01, 0x00, 0xff, 0x55], simbolo: "arrow.down"),

        .init(id: "dpi+", nome: "Aumentar DPI", grupo: "DPI", bytes: [0x02, 0x02, 0x00, 0x51], simbolo: "plus.circle"),
        .init(id: "dpi-", nome: "Diminuir DPI", grupo: "DPI", bytes: [0x02, 0x03, 0x00, 0x50], simbolo: "minus.circle"),
        .init(id: "dpi-cycle", nome: "Trocar DPI em ciclo", grupo: "DPI", bytes: [0x02, 0x01, 0x00, 0x52], simbolo: "arrow.triangle.2.circlepath"),
        .init(id: "snipe", nome: "Mira (DPI baixo ao segurar)", grupo: "DPI", bytes: [0x02, 0x04, 0x00, 0x4f], simbolo: "scope"),

        .init(id: "led_toggle", nome: "Liga e desliga a luz", grupo: "Mouse", bytes: [0x08, 0x00, 0x00, 0x4d], simbolo: "lightbulb"),
        .init(id: "profile_switch", nome: "Trocar perfil", grupo: "Mouse", bytes: [0x08, 0x01, 0x00, 0x4c], simbolo: "person.2"),
        .init(id: "polling_switch", nome: "Trocar taxa de resposta", grupo: "Mouse", bytes: [0x07, 0x00, 0x00, 0x4e], simbolo: "speedometer"),
        .init(id: "none", nome: "Nenhuma ação", grupo: "Mouse", bytes: [0x00, 0x00, 0x00, 0x55], simbolo: "nosign"),
    ]

    // Mídia (página Consumer do HID): [0x92, extra, código, extra2]
    static let midia: [OpcaoDireta] = [
        .init(id: "media_play", nome: "Tocar ou pausar", grupo: "Mídia", bytes: [0x92, 0x00, 0xcd, 0x00], simbolo: "playpause"),
        .init(id: "media_next", nome: "Próxima faixa", grupo: "Mídia", bytes: [0x92, 0x00, 0xb5, 0x00], simbolo: "forward.end"),
        .init(id: "media_prev", nome: "Faixa anterior", grupo: "Mídia", bytes: [0x92, 0x00, 0xb6, 0x00], simbolo: "backward.end"),
        .init(id: "media_stop", nome: "Parar", grupo: "Mídia", bytes: [0x92, 0x00, 0xb7, 0x00], simbolo: "stop"),
        .init(id: "media_vol_up", nome: "Aumentar volume", grupo: "Mídia", bytes: [0x92, 0x00, 0xe9, 0x00], simbolo: "speaker.plus"),
        .init(id: "media_vol_down", nome: "Diminuir volume", grupo: "Mídia", bytes: [0x92, 0x00, 0xea, 0x00], simbolo: "speaker.minus"),
        .init(id: "media_mute", nome: "Sem som", grupo: "Mídia", bytes: [0x92, 0x00, 0xe2, 0x00], simbolo: "speaker.slash"),
        .init(id: "www_back", nome: "Navegador: voltar", grupo: "Navegador", bytes: [0x92, 0x02, 0x24, 0x02], simbolo: "chevron.left"),
        .init(id: "www_forward", nome: "Navegador: avançar", grupo: "Navegador", bytes: [0x92, 0x02, 0x25, 0x02], simbolo: "chevron.right"),
        .init(id: "www_refresh", nome: "Navegador: atualizar", grupo: "Navegador", bytes: [0x92, 0x02, 0x27, 0x02], simbolo: "arrow.clockwise"),
        .init(id: "media_search", nome: "Navegador: buscar", grupo: "Navegador", bytes: [0x92, 0x02, 0x21, 0x02], simbolo: "magnifyingglass"),
    ]

    static func direta(_ id: String) -> OpcaoDireta? { diretas.first { $0.id == id } ?? midia.first { $0.id == id } }
}

enum Acao: Hashable {
    case direta(String)                         // id do Catalogo.diretas
    case midia(String)                          // id do Catalogo.midia
    case tiro(intervalo: Int, vezes: Int)       // tiro rápido: intervalo em ms (3..255), 0..3 repetições
    case teclado(mods: UInt8, teclas: [UInt8])  // atalho de teclado (códigos HID)
    case tecladoGuardado                        // atalho gravado que não deu para ler; preserva
    case bruta([UInt8])                         // valor desconhecido; preserva

    var nome: String {
        switch self {
        case .direta(let id), .midia(let id): return Catalogo.direta(id)?.nome ?? id
        case .tiro(let ms, let vezes): return "Tiro rápido (\(vezes == 0 ? "contínuo" : "\(vezes)x"), \(ms) ms)"
        case .teclado(let mods, let teclas): return Teclas.descricao(mods: mods, teclas: teclas)
        case .tecladoGuardado: return "Atalho de teclado"
        case .bruta(let b): return "Personalizado (\(hex(b)))"
        }
    }

    var simbolo: String {
        switch self {
        case .direta(let id), .midia(let id): return Catalogo.direta(id)?.simbolo ?? "questionmark"
        case .tiro: return "bolt"
        case .teclado, .tecladoGuardado: return "keyboard"
        case .bruta: return "questionmark"
        }
    }
}

// MARK: - Teclado

enum Teclas {
    // Bits dos modificadores no M913 (iguais ao HID). No Mac o "super" é o Command.
    static let ctrl: UInt8 = 0x01, shift: UInt8 = 0x02, opt: UInt8 = 0x04, cmd: UInt8 = 0x08

    static let nomes: [UInt8: String] = {
        var n: [UInt8: String] = [:]
        for (i, c) in "ABCDEFGHIJKLMNOPQRSTUVWXYZ".enumerated() { n[UInt8(0x04 + i)] = String(c) }
        for (i, c) in "1234567890".enumerated() { n[UInt8(0x1e + i)] = String(c) }
        for i in 0..<12 { n[UInt8(0x3a + i)] = "F\(i + 1)" }
        let extras: [UInt8: String] = [
            0x28: "Return", 0x29: "Esc", 0x2a: "Apagar", 0x2b: "Tab", 0x2c: "Espaço",
            0x2d: "-", 0x2e: "=", 0x2f: "[", 0x30: "]", 0x31: "\\", 0x33: ";", 0x34: "'",
            0x35: "`", 0x36: ",", 0x37: ".", 0x38: "/", 0x39: "Caps Lock",
            0x46: "Print Screen", 0x49: "Insert", 0x4a: "Home", 0x4b: "Page Up", 0x4c: "Apagar à frente",
            0x4d: "End", 0x4e: "Page Down", 0x4f: "→", 0x50: "←", 0x51: "↓", 0x52: "↑",
            0x53: "Num Lock", 0x54: "Num /", 0x55: "Num *", 0x56: "Num -", 0x57: "Num +", 0x58: "Num Enter",
            0x59: "Num 1", 0x5a: "Num 2", 0x5b: "Num 3", 0x5c: "Num 4", 0x5d: "Num 5",
            0x5e: "Num 6", 0x5f: "Num 7", 0x60: "Num 8", 0x61: "Num 9", 0x62: "Num 0", 0x63: "Num .",
        ]
        n.merge(extras) { $1 }
        return n
    }()

    // Código de tecla do Mac (NSEvent.keyCode) → código HID.
    static let doMac: [UInt16: UInt8] = [
        0: 0x04, 11: 0x05, 8: 0x06, 2: 0x07, 14: 0x08, 3: 0x09, 5: 0x0a, 4: 0x0b, 34: 0x0c, 38: 0x0d,
        40: 0x0e, 37: 0x0f, 46: 0x10, 45: 0x11, 31: 0x12, 35: 0x13, 12: 0x14, 15: 0x15, 1: 0x16, 17: 0x17,
        32: 0x18, 9: 0x19, 13: 0x1a, 7: 0x1b, 16: 0x1c, 6: 0x1d,
        18: 0x1e, 19: 0x1f, 20: 0x20, 21: 0x21, 23: 0x22, 22: 0x23, 26: 0x24, 28: 0x25, 25: 0x26, 29: 0x27,
        36: 0x28, 53: 0x29, 51: 0x2a, 48: 0x2b, 49: 0x2c, 27: 0x2d, 24: 0x2e, 33: 0x2f, 30: 0x30, 42: 0x31,
        41: 0x33, 39: 0x34, 50: 0x35, 43: 0x36, 47: 0x37, 44: 0x38,
        122: 0x3a, 120: 0x3b, 99: 0x3c, 118: 0x3d, 96: 0x3e, 97: 0x3f, 98: 0x40, 100: 0x41,
        101: 0x42, 109: 0x43, 103: 0x44, 111: 0x45,
        115: 0x4a, 116: 0x4b, 117: 0x4c, 119: 0x4d, 121: 0x4e, 124: 0x4f, 123: 0x50, 125: 0x51, 126: 0x52,
        71: 0x53, 75: 0x54, 67: 0x55, 78: 0x56, 69: 0x57, 76: 0x58,
        83: 0x59, 84: 0x5a, 85: 0x5b, 86: 0x5c, 87: 0x5d, 88: 0x5e, 89: 0x5f, 91: 0x60, 92: 0x61, 82: 0x62, 65: 0x63,
    ]

    static func descricao(mods: UInt8, teclas: [UInt8]) -> String {
        var s = ""
        if mods & 0x11 != 0 { s += "⌃" }
        if mods & 0x44 != 0 { s += "⌥" }
        if mods & 0x22 != 0 { s += "⇧" }
        if mods & 0x88 != 0 { s += "⌘" }
        let t = teclas.map { nomes[$0] ?? String(format: "0x%02x", $0) }.joined(separator: " ")
        if s.isEmpty { return t.isEmpty ? "Atalho vazio" : t }
        return t.isEmpty ? s : s + " " + t
    }
}

// MARK: - DPI

enum TabelaDPI {
    static let codigos: [Int: UInt8] = [
        100: 0x00, 200: 0x02, 300: 0x03, 400: 0x04, 500: 0x05, 600: 0x06, 700: 0x07, 800: 0x09, 900: 0x0a,
        1000: 0x0b, 1100: 0x0c, 1200: 0x0d, 1300: 0x0e, 1400: 0x10, 1500: 0x11, 1600: 0x12, 1700: 0x13,
        1800: 0x14, 1900: 0x16, 2000: 0x17, 2100: 0x18, 2200: 0x19, 2300: 0x1a, 2400: 0x1b, 2500: 0x1d,
        2600: 0x1e, 2700: 0x1f, 2800: 0x20, 2900: 0x21, 3000: 0x23, 3200: 0x26, 3600: 0x2a, 4000: 0x2f,
        4800: 0x39, 5000: 0x3b, 5500: 0x41, 6000: 0x47, 6400: 0x4c, 6600: 0x4f, 7000: 0x53, 7200: 0x56,
        7300: 0x57, 7400: 0x58, 7500: 0x59, 8000: 0x5f, 8500: 0x65, 9000: 0x6b, 9600: 0x73, 10000: 0x77,
        11000: 0x83, 12000: 0x8f, 13000: 0x9b, 14000: 0xa7, 15000: 0xb3, 16000: 0xbd,
    ]
    static let valores: [Int] = codigos.keys.sorted()
    static let porCodigo: [UInt8: Int] = Dictionary(uniqueKeysWithValues: codigos.map { ($1, $0) })

    static func maisProximo(_ v: Int) -> Int { valores.min { abs($0 - v) < abs($1 - v) } ?? 1000 }

    static func quatroBytes(_ dpi: Int) -> [UInt8] {
        let n = maisProximo(dpi)
        let c = codigos[n] ?? 0x0b
        let alto: UInt8 = n > 5000 ? 0x01 : 0x00
        return [c, c, alto, conferencia([Int(c), Int(c), Int(alto)])]
    }
}

// MARK: - Configuração lida do mouse

enum ModoLuz: Int, CaseIterable, Identifiable {
    case desligada = 0, fixa = 1, respiracao = 2, arcoIris = 3
    var id: Int { rawValue }
    var nome: String {
        switch self {
        case .desligada: return "Desligada"
        case .fixa: return "Fixa"
        case .respiracao: return "Respiração"
        case .arcoIris: return "Arco-íris"
        }
    }
}

struct CorRGB: Hashable {
    var r: UInt8, g: UInt8, b: UInt8
}

struct ConfigMouse: Equatable {
    var taxa: Int = 1000
    var dpi: [Int] = [500, 1000, 2000, 3000, 6000]
    var estagios: Int = 5
    var luz: ModoLuz = .arcoIris
    var cor = CorRGB(r: 255, g: 0, b: 0)
    var brilho: Int = 255
    var velocidade: Int = 3
    var acoes: [Acao] = Array(repeating: .direta("none"), count: 16)
    // Bytes originais de cada botão, para preservar o que não for alterado.
    var slots: [[UInt8]] = Array(repeating: [0, 0, 0, 0x55], count: 16)
}

// Botões na ordem do firmware.
enum Botoes {
    // índice do firmware → nome
    static let nomes: [Int: String] = [
        0: "Lateral 1", 1: "Lateral 2", 2: "Lateral 3", 3: "Lateral 4", 4: "Lateral 5", 5: "Lateral 6",
        6: "Botão direito", 7: "Botão esquerdo", 8: "Lateral 7", 9: "Lateral 8", 10: "Rodinha (clique)",
        11: "Botão de tiro", 12: "Lateral 9", 13: "Lateral 10", 14: "Lateral 11", 15: "Lateral 12",
    ]
    // Grade lateral 3 x 4, na ordem física (1 a 12).
    static let laterais: [Int] = [0, 1, 2, 3, 4, 5, 8, 9, 12, 13, 14, 15]
    static let principais: [Int] = [7, 6, 10, 11]

    static let enderecoTeclado: [Int] = [
        0x100, 0x120, 0x140, 0x160, 0x180, 0x1a0, 0x1c0, 0x1e0,
        0x200, 0x220, 0x240, 0x260, 0x280, 0x2a0, 0x2c0, 0x2e0,
    ]

    // Padrão de fábrica quando o botão está zerado ou com atalho ilegível.
    static let fabrica: [Int: Acao] = [
        0: .teclado(mods: 0, teclas: [0x1e]), 1: .teclado(mods: 0, teclas: [0x1f]), 2: .teclado(mods: 0, teclas: [0x20]),
        3: .teclado(mods: 0, teclas: [0x21]), 4: .teclado(mods: 0, teclas: [0x22]), 5: .teclado(mods: 0, teclas: [0x23]),
        6: .direta("right"), 7: .direta("left"), 8: .teclado(mods: 0, teclas: [0x24]), 9: .teclado(mods: 0, teclas: [0x25]),
        10: .direta("middle"), 11: .tiro(intervalo: 58, vezes: 3),
        12: .teclado(mods: 0, teclas: [0x26]), 13: .teclado(mods: 0, teclas: [0x27]),
        14: .teclado(mods: 0, teclas: [0x57]), 15: .teclado(mods: 0, teclas: [0x56]),
    ]
}

enum Decodifica {
    static func config(memoria m: [UInt8], teclados: [Int: [UInt8]]) -> ConfigMouse {
        var c = ConfigMouse()
        c.taxa = [0x01: 1000, 0x02: 500, 0x04: 250, 0x08: 125][m[0x00]] ?? 1000
        c.estagios = max(1, min(5, Int(m[0x02])))
        c.dpi = (0..<5).map { i in TabelaDPI.porCodigo[m[0x0c + i * 4]] ?? TabelaDPI.maisProximo(Int(m[0x0c + i * 4]) * 100) }
        c.cor = CorRGB(r: m[0x54], g: m[0x55], b: m[0x56])
        c.luz = ModoLuz(rawValue: Int(m[0x58])) ?? .arcoIris
        c.brilho = Int(m[0x5a])
        c.velocidade = max(1, min(5, Int(m[0x5c] == 0 ? 3 : m[0x5c])))
        for i in 0..<16 {
            let o = 0x60 + i * 4
            let slot = Array(m[o..<(o + 4)])
            c.slots[i] = slot
            c.acoes[i] = acao(slot: slot, botao: i, teclado: teclados[i])
        }
        return c
    }

    static func acao(slot ab: [UInt8], botao: Int, teclado: [UInt8]?) -> Acao {
        if ab[0] == 0x04 {
            if ab == [0x04, 0x32, 0x03, 0x1c] { return .direta("three_click") }
            return .tiro(intervalo: Int(ab[1]), vezes: Int(ab[2]))
        }
        if ab[0] == 0x00 && ab[1] == 0x00 && ab[2] == 0x00 {
            return ab[3] == 0x55 ? .direta("none") : (Botoes.fabrica[botao] ?? .direta("none"))
        }
        if let d = Catalogo.diretas.first(where: { Array($0.bytes[0..<3]) == Array(ab[0..<3]) }) { return .direta(d.id) }
        if let d = Catalogo.midia.first(where: { $0.bytes == ab }) { return .midia(d.id) }
        if ab[0] == 0x05 {
            if let t = teclado, let a = eventos(t) { return a }
            return .tecladoGuardado
        }
        return .bruta(ab)
    }

    // Lista de eventos do atalho: [quantidade, (tipo, valor, extra) ...]
    static func eventos(_ b: [UInt8]) -> Acao? {
        guard let n = b.first, n > 0, n <= 10 else { return nil }
        var mods: UInt8 = 0
        var teclas: [UInt8] = []
        for i in 0..<Int(n) {
            let o = 1 + i * 3
            guard o + 2 < b.count else { break }
            let tipo = b[o], valor = b[o + 1], extra = b[o + 2]
            switch tipo {
            case 0x80: mods |= valor
            case 0x81: if !teclas.contains(valor) { teclas.append(valor) }
            case 0x82:
                if let m = Catalogo.midia.first(where: { $0.bytes[2] == valor && ($0.bytes[1] == extra || extra == 0) }) {
                    return .midia(m.id)
                }
            default: break
            }
        }
        if mods == 0 && teclas.isEmpty { return nil }
        return .teclado(mods: mods, teclas: teclas)
    }
}

// MARK: - Montagem dos pacotes de gravação

enum Monta {
    static let marcaTeclado: [UInt8] = [0x05, 0x00, 0x00, 0x50]

    /// Pacotes dos 16 botões. `alterados` diz quais botões foram mudados; os outros
    /// mantêm exatamente os bytes que estavam no mouse.
    static func botoes(_ c: ConfigMouse, alterados: Set<Int>) -> [Pacote] {
        var slots = c.slots
        var extras: [Pacote] = []
        for i in alterados.sorted() {
            let (slot, sub) = codifica(c.acoes[i], botao: i)
            slots[i] = slot
            extras += sub
        }
        var principais: [Pacote] = []
        for k in 0..<8 {
            let dados = slots[k * 2] + slots[k * 2 + 1]
            principais.append(novoPacote(sub: M913.subGrava, endereco: 0x60 + k * 8, tamanho: 8, dados: dados))
        }
        // Os atalhos de teclado vão antes dos 8 pacotes dos botões.
        return extras + principais
    }

    static func codifica(_ a: Acao, botao: Int) -> (slot: [UInt8], sub: [Pacote]) {
        let end = Botoes.enderecoTeclado[botao]
        switch a {
        case .direta(let id):
            return (Catalogo.direta(id)?.bytes ?? [0, 0, 0, 0x55], [])
        case .tiro(let ms, let vezes):
            let s = UInt8(max(3, min(255, ms))), v = UInt8(max(0, min(3, vezes)))
            return ([0x04, s, v, conferencia([4, Int(s), Int(v)])], [])
        case .midia(let id):
            guard let m = Catalogo.direta(id) else { return ([0, 0, 0, 0x55], []) }
            let extra = m.bytes[1], codigo = m.bytes[2], extra2 = m.bytes[3]
            let ev: [UInt8] = [0x02, 0x82, codigo, extra, 0x42, codigo, extra2]
            let dados = ev + [conferencia(ev.map(Int.init))]
            return (marcaTeclado, [novoPacote(sub: M913.subGrava, endereco: end, tamanho: 8, dados: dados)])
        case .teclado(let mods, let teclas):
            return (marcaTeclado, pacotesTeclado(mods: mods, teclas: Array(teclas.prefix(3)), endereco: end))
        case .tecladoGuardado, .bruta:
            return (marcaTeclado, [])
        }
    }

    static func pacotesTeclado(mods: UInt8, teclas: [UInt8], endereco end: Int) -> [Pacote] {
        if mods == 0 && teclas.count == 1 {
            let k = teclas[0]
            let ev: [UInt8] = [0x02, 0x81, k, 0x00, 0x41, k, 0x00]
            return [novoPacote(sub: M913.subGrava, endereco: end, tamanho: 8, dados: ev + [conferencia(ev.map(Int.init))])]
        }
        if teclas.isEmpty {
            let ev: [UInt8] = [0x02, 0x80, mods, 0x00, 0x40, mods, 0x00]
            return [novoPacote(sub: M913.subGrava, endereco: end, tamanho: 8, dados: ev + [conferencia(ev.map(Int.init))])]
        }
        // Combinação: modificadores e teclas descem em ordem e sobem ao contrário.
        let bits: [UInt8] = [0x01, 0x02, 0x04, 0x08, 0x10, 0x20, 0x40, 0x80]
        var ev: [UInt8] = []
        for b in bits where mods & b != 0 { ev += [0x80, b, 0x00] }
        for k in teclas { ev += [0x81, k, 0x00] }
        for b in bits where mods & b != 0 { ev += [0x40, b, 0x00] }
        for k in teclas.reversed() { ev += [0x41, k, 0x00] }
        let quantidade = ev.count / 3
        let interna = conferencia([(quantidade + ev.reduce(0) { $0 + Int($1) }) & 0xff])

        let usados = min(9, ev.count)
        let p1 = novoPacote(sub: M913.subGrava, endereco: end, tamanho: 0x0a, dados: [UInt8(quantidade)] + Array(ev[0..<usados]))
        let resto = Array(ev[usados...])
        let p2 = novoPacote(sub: M913.subGrava, endereco: end + 0x0a, tamanho: resto.count + 1, dados: resto + [interna])
        return [p1, p2]
    }

    static func dpi(_ c: ConfigMouse) -> [Pacote] {
        let b = c.dpi.map(TabelaDPI.quatroBytes)
        let estagios = max(1, min(5, c.estagios))
        let ativos: [UInt8] = [UInt8(estagios), conferencia([estagios])]
        var p: [Pacote] = [
            novoPacote(sub: M913.subGrava, endereco: 0x0c, tamanho: 8, dados: b[0] + b[1]),
            novoPacote(sub: M913.subGrava, endereco: 0x14, tamanho: 8, dados: b[2] + b[3]),
            novoPacote(sub: M913.subGrava, endereco: 0x1c, tamanho: 4, dados: b[4]),
            novoPacote(sub: M913.subGrava, endereco: 0x02, tamanho: 2, dados: ativos),
        ]
        // Cores dos estágios: o M913 não usa, mas o programa oficial sempre grava as de fábrica.
        let cores: [[UInt8]] = [[0xff, 0, 0], [0, 0, 0xff], [0, 0xff, 0], [0xff, 0xff, 0], [0xff, 0x80, 0]]
        let q = cores.map { $0 + [conferencia($0.map(Int.init))] }
        p.append(novoPacote(sub: M913.subGrava, endereco: 0x2c, tamanho: 8, dados: q[0] + q[1]))
        p.append(novoPacote(sub: M913.subGrava, endereco: 0x34, tamanho: 8, dados: q[2] + q[3]))
        p.append(novoPacote(sub: M913.subGrava, endereco: 0x3c, tamanho: 4, dados: q[4]))
        return p
    }

    static func luz(_ c: ConfigMouse) -> [Pacote] {
        let brilho = UInt8(max(0, min(255, c.brilho)))
        let vel = UInt8(max(1, min(5, c.velocidade)))
        func principal(_ cor: [UInt8], modo: UInt8) -> Pacote {
            let dados = cor + [conferencia(cor.map(Int.init)), modo, conferencia([Int(modo)]), brilho, conferencia([Int(brilho)])]
            return novoPacote(sub: M913.subGrava, endereco: 0x54, tamanho: 8, dados: dados)
        }
        let velocidade = novoPacote(sub: M913.subGrava, endereco: 0x5c, tamanho: 2, dados: [vel, conferencia([Int(vel)])])
        let cor = [c.cor.r, c.cor.g, c.cor.b]
        switch c.luz {
        case .desligada: return [novoPacote(sub: M913.subGrava, endereco: 0x58, tamanho: 2, dados: [0x00, 0x55])]
        case .fixa: return [principal(cor, modo: 0x01)]
        case .respiracao: return [principal(cor, modo: 0x02), velocidade]
        case .arcoIris: return [principal([0xff, 0x00, 0xff], modo: 0x03), velocidade]
        }
    }

    /// Nível de DPI em uso agora (1 a 5), no endereço 0x04 contado do zero.
    static func nivelAtual(_ n: Int) -> Pacote {
        let v = UInt8(max(1, min(5, n)) - 1)
        return novoPacote(sub: M913.subGrava, endereco: 0x04, tamanho: 2, dados: [v, conferencia([Int(v)])])
    }

    static func taxa(_ hz: Int) -> Pacote {
        let codigo: UInt8 = [1000: 0x01, 500: 0x02, 250: 0x04, 125: 0x08][hz] ?? 0x01
        return novoPacote(sub: M913.subGrava, endereco: 0x00, tamanho: 2, dados: [codigo, conferencia([Int(codigo)])])
    }

    static var confirma: Pacote { novoPacote(sub: M913.subConfirma) }
    static var bateria: Pacote { novoPacote(sub: M913.subConfirma) }
    static func le(_ endereco: Int, tamanho: Int = 10) -> Pacote {
        novoPacote(sub: M913.subLe, endereco: endereco, tamanho: tamanho)
    }
}
