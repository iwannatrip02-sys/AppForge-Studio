import Foundation
import simd

struct PinchDeformer: Deformer {
    func deform(vertex: inout Vertex, at point: SculptPoint, radius: Float, strength: Float, falloff: Float, adjacency: [SIMD3<Float>]? = nil) {
        let influence = strength * falloff * point.pressure
        let toCenter = simd_normalize(point.position - vertex.position)
        vertex.position += toCenter * influence * 0.5
    }
}