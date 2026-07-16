import Foundation
import simd

/// Imán de los toques de medición (barrido device 2026-07-11: "no hay snap, no
/// sabes dónde pones el punto"). Prioridad CAD: vértice real (esquina) → punto
/// medio de arista → punto tocado tal cual. Radios en unidades de mundo, más
/// generosos que los de selección: medir premia la intención, no la puntería.
enum MeasureSnapService {

    enum SnapKind {
        case vertex      // esquina real del B-rep
        case midpoint    // punto medio de una arista
        case free        // el punto tocado, sin imán
    }

    struct Result {
        let position: SIMD3<Float>
        let kind: SnapKind
    }

    static func snap(hit: SurfaceHit, models: [Model],
                     vertexRadius: Float = 0.12,
                     midpointRadius: Float = 0.08) -> Result {
        guard hit.modelIndex >= 0, hit.modelIndex < models.count,
              let shape = models[hit.modelIndex].cadShape else {
            return Result(position: hit.position, kind: .free)
        }
        if let vi = BRepVertexPicker.vertexIndex(of: shape, nearest: hit.position,
                                                 maxDistance: vertexRadius),
           let p = BRepVertexPicker.position(of: shape, vertexIndex: vi) {
            return Result(position: p, kind: .vertex)
        }
        if let ei = BRepEdgePicker.edgeIndex(of: shape, nearest: hit.position,
                                             maxDistance: Double(midpointRadius)),
           let pts = BRepEdgePicker.polyline(of: shape, edgeIndex: ei, samples: 3),
           pts.count == 3 {
            let mid = pts[1]
            if simd_distance(mid, hit.position) <= midpointRadius {
                return Result(position: mid, kind: .midpoint)
            }
        }
        return Result(position: hit.position, kind: .free)
    }
}
