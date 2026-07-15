import Foundation
import simd

// =============================================================================
// TransformSnap — matemática PURA de la manipulación directa (Ola LiveInteraction)
// =============================================================================
//
// Extrae la aritmética que vivía privada dentro de `CADModeView` (cuantización de
// snap, transformación de ejes local/global, formateo de la lectura viva) a un
// tipo sin estado y sin dependencias de UIKit/SwiftUI, para poder testearla en
// aislamiento (tarea 8 del carril L2). `CADModeView` delega en estas funciones:
// una sola fuente de verdad tanto para la vista como para los tests.

/// Clase de magnitud que se está manipulando. Desacopla la matemática de snap del
/// enum `CADTool` completo (solo importan estas tres semánticas).
enum TransformSnapKind: Equatable {
    /// Distancia lineal (Mover / push-pull) — cuantiza al paso de rejilla.
    case length
    /// Ángulo en RADIANES (Rotar) — cuantiza al incremento angular.
    case angle
    /// Factor de escala multiplicativo (Escalar) — cuantiza a pasos de 0.25.
    case factor
}

/// Funciones puras de la manipulación directa. Sin estado, sin efectos.
enum TransformSnap {

    /// Paso de escala fijo (factores redondos de 0.25). Constante del sistema.
    static let scaleStep: Double = 0.25
    /// Factor mínimo de escala tras cuantizar (evita colapsar el cuerpo a 0).
    static let minScaleFactor: Double = 0.05

    // MARK: - Cuantización de snap (tarea 2)

    /// Cuantiza un escalar a incrementos redondos SI el snap está activo.
    ///   · `.length` → múltiplo del `gridStep` (mínimo 0.01).
    ///   · `.angle`  → múltiplo de `angleStepDegrees` (convertido a rad; ≤0 ⇒ 15°).
    ///   · `.factor` → múltiplo de `scaleStep`, saturado a `minScaleFactor`.
    /// Snap REAL: devuelve el valor que se APLICA, no un placebo visual.
    static func quantize(_ value: Double,
                         kind: TransformSnapKind,
                         enabled: Bool,
                         gridStep: Double,
                         angleStepDegrees: Double) -> Double {
        guard enabled else { return value }
        switch kind {
        case .length:
            let step = max(0.01, gridStep)
            return (value / step).rounded() * step
        case .angle:
            let deg = angleStepDegrees > 0 ? angleStepDegrees : 15.0
            let stepRad = deg * .pi / 180
            return (value / stepRad).rounded() * stepRad
        case .factor:
            return max(minScaleFactor, (value / scaleStep).rounded() * scaleStep)
        }
    }

    /// ¿El valor cuantizado cruzó a un NUEVO detente respecto al último emitido?
    /// Usado para disparar el tick háptico solo al cambiar de incremento (no cada
    /// frame). `last == nil` (primer frame del gesto) NO cuenta como cruce.
    static func crossedDetent(_ snapped: Double, last: Double?) -> Bool {
        guard let last = last else { return false }
        return abs(snapped - last) > 1e-9
    }

    // MARK: - Transformación de ejes local/global (tarea 3)

    /// Resuelve el eje del gizmo al espacio de MUNDO según el toggle local/global.
    ///   · global → el eje tal cual (ejes de mundo fijos).
    ///   · local  → el eje rotado por la orientación del cuerpo (`rotation`), de
    ///     modo que los ejes viajan con el sólido.
    /// `axis == nil` (drag libre) se propaga como nil.
    static func resolveAxis(_ axis: SIMD3<Float>?,
                            local: Bool,
                            rotation: simd_quatf) -> SIMD3<Float>? {
        guard let axis = axis else { return nil }
        if local {
            return simd_normalize(rotation.act(axis))
        }
        return axis
    }

    // MARK: - Formateo de la lectura viva (tarea 1 / 4)

    /// Formatea el escalar activo para el HUD flotante y la guía de la barra.
    ///   · `.length` → "%+.2f"     (p.ej. "+1.50")
    ///   · `.angle`  → "%+.1f°"    (radianes → grados con signo)
    ///   · `.factor` → "×%.2f"     (p.ej. "×1.25")
    static func readout(_ scalar: Double, kind: TransformSnapKind) -> String {
        switch kind {
        case .length: return String(format: "%+.2f", scalar)
        case .angle:  return String(format: "%+.1f°", scalar * 180 / .pi)
        case .factor: return String(format: "×%.2f", scalar)
        }
    }
}
