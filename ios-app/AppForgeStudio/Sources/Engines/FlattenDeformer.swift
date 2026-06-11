import Foundation
import simd

struct FlattenDeformer: Deformer {
    func deform(vertex: inout Vertex, at point: SculptPoint, radius: Float, strength: Float, falloff: Float, adjacency: [SIMD3<Float>]? = nil) {
        let influence = strength * falloff * point.pressure
        let dir = simd_normalize(point.position - vertex.position)
        vertex.position -= dir * influence
    }
}