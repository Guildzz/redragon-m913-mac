import AppKit
import ApplicationServices

/// Pelo receptor sem fio, o macOS não junta o ⌘, ⌥, ⌃ ou ⇧ segurado no teclado com a tecla
/// que vem do mouse: segurar ⌘ e apertar a lateral do F1 sai só F1. Este vigia acrescenta à
/// tecla os modificadores que estão apertados no teclado naquele momento.
/// Precisa da permissão de Acessibilidade, que o usuário libera em Ajustes do Sistema.
@MainActor
final class JuntaModificadores: ObservableObject {
    private static let chave = "juntaModificadores"
    nonisolated private static let modificadores: CGEventFlags = [.maskCommand, .maskAlternate, .maskControl, .maskShift]
    nonisolated(unsafe) private static var tapAtual: CFMachPort?

    @Published var ligado: Bool {
        didSet { UserDefaults.standard.set(ligado, forKey: Self.chave); atualiza() }
    }
    @Published private(set) var temPermissao = AXIsProcessTrusted()
    private var fonte: CFRunLoopSource?
    private var vigia: Timer?

    init() {
        ligado = UserDefaults.standard.object(forKey: Self.chave) as? Bool ?? true
        atualiza()
    }

    func pedePermissao() {
        let opcoes = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        temPermissao = AXIsProcessTrustedWithOptions(opcoes)
        if !temPermissao, let u = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(u)
        }
        atualiza()
    }

    private func atualiza() {
        temPermissao = AXIsProcessTrusted()
        if ligado && temPermissao { liga() } else { desliga() }
        // Sem aviso do sistema quando a permissão chega: confere de tempos em tempos.
        if ligado && !temPermissao {
            if vigia == nil {
                vigia = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
                    MainActor.assumeIsolated {
                        guard let self else { return }
                        if AXIsProcessTrusted() != self.temPermissao { self.atualiza() }
                    }
                }
            }
        } else {
            vigia?.invalidate()
            vigia = nil
        }
    }

    private func liga() {
        guard Self.tapAtual == nil else { return }
        let mascara = CGEventMask((1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.keyUp.rawValue))
        guard let tap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap,
                                          eventsOfInterest: mascara, callback: { _, tipo, evento, _ in
            if tipo == .tapDisabledByTimeout || tipo == .tapDisabledByUserInput {
                if let t = JuntaModificadores.tapAtual { CGEvent.tapEnable(tap: t, enable: true) }
            } else {
                JuntaModificadores.junta(evento)
            }
            return Unmanaged.passUnretained(evento)
        }, userInfo: nil) else {
            depura("acessibilidade: não deu para criar o vigia de teclas")
            return
        }
        Self.tapAtual = tap
        fonte = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), fonte, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        depura("acessibilidade: juntando modificadores")
    }

    private func desliga() {
        guard let tap = Self.tapAtual else { return }
        CGEvent.tapEnable(tap: tap, enable: false)
        if let fonte { CFRunLoopRemoveSource(CFRunLoopGetMain(), fonte, .commonModes) }
        fonte = nil
        Self.tapAtual = nil
    }

    /// O teclado de verdade já manda os modificadores que estão apertados. Uma tecla de hardware
    /// que chega sem eles, com eles segurados no teclado, veio de outro aparelho: o mouse.
    nonisolated private static func junta(_ e: CGEvent) {
        if depurando, e.type == .keyDown {
            depura("tap: tecla=\(e.getIntegerValueField(.keyboardEventKeycode)) flags=\(String(e.flags.rawValue, radix: 16)) origem=\(e.getIntegerValueField(.eventSourceStateID)) teclado=\(e.getIntegerValueField(.keyboardEventKeyboardType)) hid=\(String(CGEventSource.flagsState(.hidSystemState).rawValue, radix: 16)) sessao=\(String(CGEventSource.flagsState(.combinedSessionState).rawValue, radix: 16))")
        }
        guard e.getIntegerValueField(.eventSourceStateID) == Int64(CGEventSourceStateID.hidSystemState.rawValue) else { return }
        // O estado de hardware é separado por aparelho (o do mouse não tem o ⌘ do teclado);
        // o da sessão junta todos os teclados.
        let sessao = CGEventSource.flagsState(.combinedSessionState)
        let segurados = sessao.intersection(modificadores)
        let faltam = segurados.subtracting(e.flags)
        guard !faltam.isEmpty else { return }
        // Leva junto os bits de lado (⌘ esquerdo, ⌃ direito...), que alguns jogos conferem.
        let lados = CGEventFlags(rawValue: sessao.rawValue & 0x207f)
        e.flags.formUnion(faltam.union(lados))
        depura("acessibilidade: tecla \(e.getIntegerValueField(.keyboardEventKeycode)) ganhou \(String(faltam.rawValue, radix: 16))")
    }
}
