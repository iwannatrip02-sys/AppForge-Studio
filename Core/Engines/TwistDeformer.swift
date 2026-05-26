import Foundation
import simd

struct TwistDeformer: Deformer {
    func deform(vertex: inout Vertex, at point: SculptPoint, radius: Float, strength: Float, falloff: Float) {
        let influence = strength * falloff * point.pressure
        let dir = vertex.position - point.position
        let angle = influence * 0.5
        let cosA = cos(angle)
        let sinA = sin(angle)
        let x = dir.x * cosA - dir.z * sinA
        let z = dir.x * sinA + dir.z * cosA
        vertex.position.x = point.position.x + x
        vertex.position.z = point.position.z + z
    }
}