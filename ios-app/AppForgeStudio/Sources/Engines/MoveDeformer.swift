import Foundation
import simd

struct MoveDeformer: Deformer {
    func deform(vertex: inout Vertex, at point: SculptPoint, radius: Float, strength: Float, falloff: Float, adjacency: [SIMD3<Float>]? = nil) {
        let influence = strength * falloff * point.pressure
        let direction = simd_normalize(vertex.position - point.position)
        vertex.position += direction * influence
    }
}