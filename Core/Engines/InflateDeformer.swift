import Foundation
import simd

struct InflateDeformer: Deformer {
    func deform(vertex: inout Vertex, at point: SculptPoint, radius: Float, strength: Float, falloff: Float) {
        let influence = strength * falloff * point.pressure
        vertex.position += vertex.normal * influence
    }
}