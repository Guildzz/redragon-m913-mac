import Foundation

/// O mouse só informa a bateria de 10 em 10%. Para dar o tempo restante, o app mede quanto
/// tempo de uso o mouse leva para cair 10% e guarda a média entre uma sessão e outra.
struct EstimativaBateria {
    private static let chave = "minutosPor10"
    /// Leituras com intervalo maior que isso não contam: o Mac dormiu, o mouse ficou desligado
    /// ou o app estava fechado.
    private static let intervaloMaximo: TimeInterval = 5 * 60

    /// Média aprendida de minutos de uso para cada 10%.
    private(set) var minutosPor10: Double?
    private var ultimoNivel: Int?
    private var ultimaLeitura: Date?
    /// Tempo de uso desde a última queda vista. Nil até ver a primeira queda.
    private var usoDesdeQueda: TimeInterval?

    init() {
        let v = UserDefaults.standard.double(forKey: Self.chave)
        minutosPor10 = v > 0 ? v : nil
    }

    mutating func registra(nivel: Int, carregando: Bool, em agora: Date = Date()) {
        defer { ultimoNivel = nivel; ultimaLeitura = agora }
        if carregando { usoDesdeQueda = nil; return }

        if let t = ultimaLeitura, let uso = usoDesdeQueda {
            let passou = agora.timeIntervalSince(t)
            if passou > 0 && passou <= Self.intervaloMaximo { usoDesdeQueda = uso + passou }
        }
        guard let antes = ultimoNivel, nivel != antes else { return }

        if nivel == antes - 10 {
            // Um degrau inteiro medido: só vale se a medição começou numa queda anterior.
            if let uso = usoDesdeQueda, uso >= 10 * 60, uso <= 72 * 3600 { aprende(uso / 60) }
            usoDesdeQueda = 0
        } else {
            // Subiu (oscilação na divisa) ou pulou mais de um degrau: recomeça a medir.
            usoDesdeQueda = nil
        }
    }

    private mutating func aprende(_ minutos: Double) {
        let novo = minutosPor10.map { $0 * 0.6 + minutos * 0.4 } ?? minutos
        minutosPor10 = novo
        UserDefaults.standard.set(novo, forKey: Self.chave)
    }

    /// Tempo de uso que ainda resta, em segundos. Nil enquanto não aprendeu a média.
    func restante(nivel: Int) -> TimeInterval? {
        guard let m = minutosPor10, nivel > 0 else { return nil }
        let degraus = Double(nivel) / 10
        // Logo depois de cair para 40%, sobra quase o degrau inteiro; sem saber quando caiu, meio degrau.
        let gasto = usoDesdeQueda.map { min($0 / 60, m) } ?? m / 2
        let minutos = max(m * degraus - gasto, m * (degraus - 1), 0)
        return minutos * 60
    }

    static func texto(_ segundos: TimeInterval) -> String {
        let min = Int(segundos / 60)
        if min < 15 { return "Menos de 15 min restantes" }
        if min < 60 { return "Cerca de \(Int((Double(min) / 5).rounded()) * 5) min restantes" }
        if min < 10 * 60 {
            let meias = Int((Double(min) / 30).rounded())
            let h = meias / 2
            return meias % 2 == 0 ? "Cerca de \(h) h restantes" : "Cerca de \(h) h 30 min restantes"
        }
        if min < 48 * 60 { return "Cerca de \(Int((Double(min) / 60).rounded())) h restantes" }
        return "Cerca de \(Int((Double(min) / 1440).rounded())) dias restantes"
    }
}
