import Foundation
import simd

struct SmoothDeformer: Deformer {
    func deform(vertex: inout Vertex, at point: SculptPoint, radius: Float, strength: Float, falloff: Float) {
        let influence = strength * falloff * point.pressure
        vertex.position = simd_mix(vertex.position, point.position, influence * 0.1)
    }
}