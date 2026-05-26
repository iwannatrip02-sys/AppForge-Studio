import Foundation
import simd

struct BendDeformer: Deformer {
    func deform(vertex: inout Vertex, at point: SculptPoint, radius: Float, strength: Float, falloff: Float, adjacency: [SIMD3<Float>]? = nil) {
        let influence = strength * falloff * point.pressure
        let rel = vertex.position - point.position
        let angle = influence * rel.z
        let cosA = cos(angle)
        let sinA = sin(angle)
        vertex.position.x = point.position.x + rel.x * cosA - rel.z * sinA
        vertex.position.z = point.position.z + rel.x * sinA + rel.z * cosA
    }
}
