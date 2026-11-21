import SwiftUI
import ServiceManagement

extension Notification.Name {
    static let reabriuApp = Notification.Name("M913.reabriu")
}

final class Delegado: NSObject, NSApplicationDelegate {
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        NotificationCenter.default.post(name: .reabriuApp, object: nil)
        return true
    }
}

@main
struct M913App: App {
    @NSApplicationDelegateAdaptor(Delegado.self) private var delegado
    @StateObject private var mouse = Mouse()

    private var visivel: Binding<Bool> {
        Binding(get: { mouse.ligado || mouse.semPermissao || mouse.mostrarSempre },
                set: { _ in })
    }

    var body: some Scene {
        MenuBarExtra(isInserted: visivel) {
            MenuBateria().environmentObject(mouse)
        } label: {
            RotuloBarra(conexao: mouse.conexao, bateria: mouse.bateria, carregando: mouse.carregando)
        }
        .menuBarExtraStyle(.window)

        Window("Red Dragon M913", id: "config") {
            JanelaConfig()
                .environmentObject(mouse)
                .frame(minWidth: 760, minHeight: 560)
        }
        .windowResizability(.contentMinSize)
        .defaultSize(width: 860, height: 620)
    }
}

// MARK: - Barra do topo

struct RotuloBarra: View {
    let conexao: Conexao
    let bateria: Int?
    let carregando: Bool

    var body: some View {
        // A barra do topo aceita uma imagem só: logo e raio vão juntos.
        HStack(spacing: 4) {
            Image(nsImage: carregando && conexao != .desconectado ? LogoRedragon.carregando : LogoRedragon.barra)
            if conexao != .desconectado, let b = bateria {
                Text("\(b)%").monospacedDigit()
            }
        }
    }
}

enum IconeBateria {
    static func nome(_ b: Int, carregando: Bool) -> String {
        if carregando { return "battery.100percent.bolt" }
        switch b {
        case ..<13: return "battery.0percent"
        case ..<38: return "battery.25percent"
        case ..<63: return "battery.50percent"
        case ..<88: return "battery.75percent"
        default: return "battery.100percent"
        }
    }

    static func cor(_ b: Int, carregando: Bool) -> Color {
        if carregando { return .green }
        if b <= 20 { return .red }
        if b <= 40 { return .orange }
        return .primary
    }
}

struct MenuBateria: View {
    @EnvironmentObject var mouse: Mouse
    @Environment(\.openWindow) private var abreJanela
    @State private var abreNoLogin = SMAppService.mainApp.status == .enabled

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: "computermouse.fill")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Red Dragon M913").font(.headline)
                    Text(textoConexao).font(.caption).foregroundStyle(.secondary)
                }
            }

            if mouse.semPermissao {
                AvisoPermissao()
            } else if mouse.conexao != .desconectado {
                PainelBateria()
            }

            if let c = mouse.config, mouse.conexao != .desconectado {
                VStack(alignment: .leading, spacing: 6) {
                    Text("DPI").font(.caption).foregroundStyle(.secondary)
                    HStack(spacing: 6) {
                        ForEach(0..<c.estagios, id: \.self) { i in
                            Text(TextoDPI.curto(c.dpi[i]))
                                .font(.caption.monospacedDigit())
                                .padding(.horizontal, 7).padding(.vertical, 3)
                                .background(.quaternary, in: Capsule())
                        }
                    }
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Button {
                    abreJanela(id: "config")
                    NSApp.activate(ignoringOtherApps: true)
                } label: {
                    Label("Configurar botões, DPI e luz", systemImage: "slider.horizontal.3")
                }
                .buttonStyle(.plain)
                .disabled(mouse.conexao == .desconectado)

                Toggle("Abrir ao ligar o Mac", isOn: $abreNoLogin)
                    .toggleStyle(.checkbox)
                    .onChange(of: abreNoLogin) { _, sim in
                        do { if sim { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() } }
                        catch { abreNoLogin = SMAppService.mainApp.status == .enabled }
                    }

                Button("Sair") { NSApp.terminate(nil) }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .frame(width: 280)
        .task { await mouse.atualizaBateria() }
    }

    var textoConexao: String {
        switch mouse.conexao {
        case .desconectado: return mouse.semPermissao ? "Falta uma permissão do macOS" : "Receptor não encontrado"
        case .semFio: return "Sem fio (2.4 GHz)"
        case .cabo: return "Pelo cabo"
        }
    }
}

struct PainelBateria: View {
    @EnvironmentObject var mouse: Mouse

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                if let b = mouse.bateria {
                    Text("\(b)%")
                        .font(.system(size: 28, weight: .semibold, design: .rounded).monospacedDigit())
                    Spacer()
                    if mouse.carregando {
                        Label("Carregando", systemImage: "bolt.fill")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.green)
                    } else if b <= 20 {
                        Label("Bateria baixa", systemImage: "exclamationmark.triangle.fill")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.red)
                    }
                } else {
                    Text("Lendo a bateria…").foregroundStyle(.secondary)
                }
            }
            if let b = mouse.bateria {
                BarraBateria(nivel: b, carregando: mouse.carregando)
            }
            if let quando = mouse.atualizadoEm {
                Text("Atualizado \(quando.formatted(.relative(presentation: .named)))")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }
}

struct BarraBateria: View {
    let nivel: Int
    let carregando: Bool

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<10, id: \.self) { i in
                RoundedRectangle(cornerRadius: 2)
                    .fill(i < nivel / 10 ? IconeBateria.cor(nivel, carregando: carregando) : Color.secondary.opacity(0.18))
                    .frame(height: 6)
            }
        }
        .animation(.easeOut(duration: 0.25), value: nivel)
    }
}

enum TextoDPI {
    static func curto(_ v: Int) -> String {
        v >= 1000 && v % 1000 == 0 ? "\(v / 1000)K" : (v >= 1000 ? String(format: "%.1fK", Double(v) / 1000) : "\(v)")
    }
}

struct AvisoPermissao: View {
    @EnvironmentObject var mouse: Mouse

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Libere o app em Monitoramento de Entrada")
                .font(.subheadline.weight(.semibold))
            Text("O receptor do mouse se apresenta como teclado, então o macOS pede essa permissão. Ligue \"Red Dragon M913\" na lista. O app conecta sozinho em seguida.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Button("Abrir Ajustes do Sistema") { mouse.abreAjustesDePermissao() }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
        }
    }
}

enum LogoRedragon {
    static let carregando: NSImage = {
        let logo = barra
        let raio = NSImage(systemSymbolName: "bolt.fill", accessibilityDescription: nil)?
            .withSymbolConfiguration(.init(pointSize: 9, weight: .bold))
        let i = NSImage(size: NSSize(width: 25, height: 16), flipped: false) { r in
            logo.draw(in: NSRect(x: 0, y: 0, width: 16, height: 16))
            if let raio {
                let t = raio.size
                raio.draw(in: NSRect(x: 18, y: (16 - t.height) / 2, width: t.width, height: t.height))
            }
            return true
        }
        i.isTemplate = true
        i.accessibilityDescription = "Red Dragon M913 carregando"
        return i
    }()

    static let barra: NSImage = {
        let tamanho = NSSize(width: 16, height: 16)
        guard let url = Bundle.main.url(forResource: "redragon", withExtension: "svg"),
              let svg = NSImage(contentsOf: url) else {
            let i = NSImage(systemSymbolName: "computermouse.fill", accessibilityDescription: "Red Dragon")!
            i.isTemplate = true
            return i
        }
        let i = NSImage(size: tamanho, flipped: false) { r in svg.draw(in: r); return true }
        i.isTemplate = true
        i.accessibilityDescription = "Red Dragon M913"
        return i
    }()
}
