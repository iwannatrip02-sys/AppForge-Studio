import Foundation
import simd

struct CreaseDeformer: Deformer {
    func deform(vertex: inout Vertex, at point: SculptPoint, radius: Float, strength: Float, falloff: Float) {
        let influence = strength * falloff * point.pressure
        let dir = simd_normalize(vertex.position - point.position)
        vertex.position += dir * influence
    }
}