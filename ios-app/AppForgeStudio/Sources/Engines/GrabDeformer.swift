import Foundation
import simd

struct GrabDeformer: Deformer {
    func deform(vertex: inout Vertex, at point: SculptPoint, radius: Float, strength: Float, falloff: Float) {
        let influence = strength * falloff * point.pressure
        vertex.position += point.normal * influence
    }
}