import Foundation
import OCCTSwift
import OSLog

private let logger = Logger(subsystem: "com.appforgestudio", category: "RobustBoolean")

/// Punto ÚNICO de paso de los booleanos B-rep de la app, blindado con las dos
/// mitigaciones que FreeCAD tardó años en aprender (informe motores-kernels):
///
///   1. **Fuzzy tolerance** (`SetFuzzyValue` vía `fuzzyValue:` en OCCTSwift): los
///      booleanos de OCCT fallan o producen sólidos inválidos cuando dos caras son
///      COPLANARES / casi-tangentes (caso clásico: dos cajas pegadas exactamente en
///      una cara). Reintentar con una tolerancia fuzzy pequeña y creciente
///      (1e-6 → 1e-4) fusiona esas caras limpiamente.
///   2. **ShapeFix** (`Shape.fixed(...)`, wrapper de `ShapeFix_Shape`): si el
///      resultado sale con topología inválida (`isValid == false`), un pase de
///      curación lo repara antes de devolverlo aguas abajo (mallado / features).
///
/// Contrato: devuelve un `CADShape` VÁLIDO (isValid + volumen finito no nulo) o
/// `nil` honesto si ninguna escala de fuzzy ni el ShapeFix logran un sólido sano.
/// Nunca devuelve una shape inválida silenciosa (la lección de los booleanos
/// frágiles: un resultado "no-nil pero podrido" envenena todo lo que viene después).
enum RobustBoolean {

    /// Operación booleana canónica.
    enum Op {
        case union, subtract, intersect

        func apply(_ a: CADShape, _ b: CADShape, fuzzy: Double) -> CADShape? {
            switch self {
            case .union:     return a.union(b, fuzzyValue: fuzzy)
            case .subtract:  return a.subtracting(b, fuzzyValue: fuzzy)
            case .intersect: return a.intersection(b, fuzzyValue: fuzzy)
            }
        }
    }

    /// Escalas de fuzzy tolerance probadas en orden. `0` = tolerancia por defecto
    /// de OCCT (el camino rápido normal). Las positivas van de menos a más agresivo:
    /// la mínima que ya resuelva el caso coplanar gana (no sobre-tolerar).
    static let fuzzyLadder: [Double] = [0, 1e-6, 1e-5, 1e-4]

    // MARK: - API pública (punto único de paso)

    static func union(_ a: CADShape, _ b: CADShape) -> CADShape? {
        perform(.union, a, b)
    }

    static func subtract(_ a: CADShape, _ b: CADShape) -> CADShape? {
        perform(.subtract, a, b)
    }

    static func intersect(_ a: CADShape, _ b: CADShape) -> CADShape? {
        perform(.intersect, a, b)
    }

    // MARK: - Núcleo

    /// Ejecuta el booleano con reintentos de fuzzy y rescate por ShapeFix.
    static func perform(_ op: Op, _ a: CADShape, _ b: CADShape) -> CADShape? {
        for fuzzy in fuzzyLadder {
            guard let raw = op.apply(a, b, fuzzy: fuzzy) else {
                // La op ni siquiera devolvió shape con esta tolerancia → sube el fuzzy.
                continue
            }

            if isSane(raw) {
                if fuzzy > 0 {
                    logger.info("[RobustBoolean] \(String(describing: op)) resuelto con fuzzy=\(fuzzy)")
                }
                return raw
            }

            // Salió shape pero con topología inválida: intenta curarla con ShapeFix
            // (ShapeFix_Shape) antes de escalar el fuzzy.
            if let healed = raw.fixed(), isSane(healed) {
                logger.info("[RobustBoolean] \(String(describing: op)) rescatado con ShapeFix (fuzzy=\(fuzzy))")
                return healed
            }
            // Si ni curada sirve, el bucle sube al siguiente fuzzy.
        }

        logger.warning("[RobustBoolean] \(String(describing: op)) falló en todas las escalas de fuzzy + ShapeFix — geometría degenerada, nil honesto")
        return nil
    }

    // MARK: - Validación

    /// Una shape es "sana" para seguir aguas abajo si es topológicamente válida y
    /// tiene un volumen finito (el kernel devuelve `volume == nil` en geometría
    /// degenerada). Volumen exactamente 0 se acepta (una intersección vacía es un
    /// resultado legítimo), pero NaN/negativo/nil no.
    static func isSane(_ shape: CADShape) -> Bool {
        guard shape.isValid else { return false }
        guard let v = shape.volume, v.isFinite, v >= 0 else { return false }
        return true
    }
}
