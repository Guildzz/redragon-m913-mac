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

    var body: some View {
        let mudancas = mouse.alteracoes
        HStack(spacing: 12) {
            if mouse.gravando {
                ProgressView().controlSize(.small)
                Text("Gravando no mouse…").foregroundStyle(.secondary)
            } else if let a = mouse.aviso {
                Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                Text(a).foregroundStyle(.secondary).lineLimit(2)
            } else if mudancas.isEmpty {
                Image(systemName: "checkmark.circle").foregroundStyle(.secondary)
                Text("Tudo igual ao que está gravado no mouse").foregroundStyle(.secondary)
            } else {
                Circle().fill(.orange).frame(width: 7, height: 7)
                Text("Alterado: " + mudancas.joined(separator: ", "))
            }
            Spacer()
            Menu {
                Button("Ler de novo do mouse") { Task { await mouse.leConfig() } }
                Button("Voltar ao padrão de fábrica") { mouse.voltaFabrica() }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .disabled(mouse.gravando)
            Button("Desfazer") { mouse.desfaz() }
                .disabled(mudancas.isEmpty || mouse.gravando)
            Button("Gravar no mouse") { Task { await mouse.grava() } }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut("s", modifiers: .command)
                .disabled(mudancas.isEmpty || mouse.gravando)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.bar)
        .overlay(alignment: .top) { Divider() }
    }
}

// MARK: - Botões

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
                Picker("Níveis em uso", selection: $mouse.rascunho.estagios) {
                    ForEach(1...5, id: \.self) { Text("\($0)").tag($0) }
                }
                .pickerStyle(.segmented)
            } footer: {
                Text("O botão de DPI passa só pelos níveis em uso. As luzinhas vermelhas ao lado dele mostram o nível: nenhuma acesa é o 1, quatro acesas é o 5.")
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

    private var cor: Binding<Color> {
        Binding(
            get: { let c = mouse.rascunho.cor; return Color(red: Double(c.r) / 255, green: Double(c.g) / 255, blue: Double(c.b) / 255) },
            set: { nova in
                guard let rgb = NSColor(nova).usingColorSpace(.sRGB) else { return }
                mouse.rascunho.cor = CorRGB(r: UInt8(max(0, min(255, rgb.redComponent * 255))),
                                            g: UInt8(max(0, min(255, rgb.greenComponent * 255))),
                                            b: UInt8(max(0, min(255, rgb.blueComponent * 255))))
            })
    }

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
                    ColorPicker("Cor", selection: cor, supportsOpacity: false)
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
