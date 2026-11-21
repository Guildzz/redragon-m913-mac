import Foundation
import IOKit.ps

// Funções públicas do IOKit (IOPowerSources.h) que não vêm declaradas para Swift.
@_silgen_name("IOPSCreatePowerSource")
private func IOPSCreatePowerSource(_ saida: UnsafeMutablePointer<OpaquePointer?>) -> Int32
@_silgen_name("IOPSSetPowerSourceDetails")
private func IOPSSetPowerSourceDetails(_ fonte: OpaquePointer, _ detalhes: CFDictionary) -> Int32
@_silgen_name("IOPSReleasePowerSource")
private func IOPSReleasePowerSource(_ fonte: OpaquePointer) -> Int32

/// Informa a bateria do mouse ao macOS como acessório, ao lado do Magic Mouse e do teclado.
@MainActor
final class BateriaSistema {
    private var fonte: OpaquePointer?

    func publica(nivel: Int, carregando: Bool, cabo: Bool, restante: TimeInterval? = nil) {
        if fonte == nil {
            var f: OpaquePointer?
            guard IOPSCreatePowerSource(&f) == 0, let f else { return }
            fonte = f
        }
        let detalhes: [String: Any] = [
            kIOPSNameKey: "Red Dragon M913",
            kIOPSTypeKey: "Accessory Source",
            kIOPSTransportTypeKey: "USB",
            kIOPSPowerSourceStateKey: cabo ? kIOPSACPowerValue : kIOPSBatteryPowerValue,
            kIOPSCurrentCapacityKey: nivel,
            kIOPSMaxCapacityKey: 100,
            kIOPSIsChargingKey: carregando,
            kIOPSIsPresentKey: true,
            kIOPSTimeToEmptyKey: restante.map { Int($0 / 60) } ?? -1,
            "Accessory Category": "Mouse",
        ]
        if let fonte { _ = IOPSSetPowerSourceDetails(fonte, detalhes as CFDictionary) }
    }

    func remove() {
        if let fonte { _ = IOPSReleasePowerSource(fonte) }
        fonte = nil
    }
}
