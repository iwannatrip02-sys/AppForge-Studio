import Foundation
import simd
import OCCTSwift

/// Medición de ingeniería de lo que hay seleccionado.
///
/// Los campos son opcionales a propósito: una arista NO tiene volumen, y fingir
/// un 0 es exactamente el defecto que esto viene a corregir (la barra de Medir
/// mostraba `Area: 0.00 mm²` y `Volumen: 0.000 mm³` FIJOS, porque se calculaban
/// en una rama inalcanzable del motor de malla placebo). `nil` = no aplica, y la
/// UI simplemente no lo muestra.
struct CADMeasurement: Equatable {
    /// Volumen del sólido. Solo para un cuerpo.
    var volume: Double?
    /// Cuerpo → superficie TOTAL. Cara → área de esa cara.
    var area: Double?
    /// Arista → su longitud. Cara → perímetro de su contorno exterior.
    var length: Double?
    /// Qué se midió, para que el número nunca sea ambiguo ("Cara 3", "Arista 7").
    var label: String
}

/// Mide el objetivo seleccionado a partir del B-rep — la fuente de verdad de
/// ingeniería — y no de la malla de display, que es solo su teselado.
///
/// Reutiliza `TransformTarget` como resolver de selección para que Medir opere
/// exactamente sobre lo mismo que el gizmo y las features: una sola noción de
/// "lo que está seleccionado" en todo el CAD.
enum MeasureService {

    /// `nil` si el objetivo no tiene B-rep (cuerpo esculpido/importado) o el
    /// índice de cara/arista quedó fuera de rango tras una edición.
    static func measure(target: TransformTarget, in models: [Model]) -> CADMeasurement? {
        let idx = target.modelIndex
        guard idx >= 0, idx < models.count else { return nil }
        let model = models[idx]
        guard let shape = model.cadShape else { return nil }

        switch target {
        case .body:
            let m = shape.measure()
            return CADMeasurement(volume: shape.volume,
                                  area: m.totalFaceArea,
                                  length: nil,
                                  label: model.name)

        case .face(_, let faceIndex):
            let m = shape.measure()
            guard faceIndex >= 0, faceIndex < m.faceAreas.count else { return nil }
            let perimeter = faceIndex < m.facePerimeters.count
                ? m.facePerimeters[faceIndex] : nil
            return CADMeasurement(volume: nil,
                                  area: m.faceAreas[faceIndex],
                                  length: perimeter,
                                  label: "Cara \(faceIndex)")

        case .edge(_, let edgeIndex):
            let m = shape.measure()
            guard edgeIndex >= 0, edgeIndex < m.edgeLengths.count else { return nil }
            return CADMeasurement(volume: nil,
                                  area: nil,
                                  length: m.edgeLengths[edgeIndex],
                                  label: "Arista \(edgeIndex)")

        case .vertex(_, let vertexIndex):
            // Un vértice no tiene magnitud que medir; se identifica y ya.
            return CADMeasurement(volume: nil, area: nil, length: nil,
                                  label: "Vértice \(vertexIndex)")
        }
    }

    /// Líneas ya formateadas para la barra, SOLO de lo que aplica. Se devuelve
    /// vacío en vez de ceros: cero es un número, y un número falso es peor que
    /// no mostrar nada.
    static func readout(_ measurement: CADMeasurement) -> [String] {
        var lines: [String] = []
        if let l = measurement.length {
            lines.append(String(format: "Longitud: %.2f mm", l))
        }
        if let a = measurement.area {
            lines.append(String(format: "Área: %.2f mm²", a))
        }
        if let v = measurement.volume {
            lines.append(String(format: "Volumen: %.3f mm³", v))
        }
        return lines
    }
}
