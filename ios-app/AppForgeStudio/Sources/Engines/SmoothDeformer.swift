import Foundation
import simd

struct SmoothDeformer: Deformer {
    func deform(vertex: inout Vertex, at point: SculptPoint, radius: Float, strength: Float, falloff: Float, adjacency: [SIMD3<Float>]? = nil) {
        let impactDistance = simd_distance(vertex.position, point.position)
        let influence = (1.0 - impactDistance / radius) * falloff * point.pressure
        
        if let neighbors = adjacency, !neighbors.isEmpty {
            var avgPosition = SIMD3<Float>.zero
            for neighborPos in neighbors {
                avgPosition += neighborPos
            }
            avgPosition /= Float(neighbors.count)
            vertex.position = simd_mix(vertex.position, avgPosition, SIMD3<Float>(repeating: influence * strength))
        } else {
            vertex.position = simd_mix(vertex.position, point.position, SIMD3<Float>(repeating: influence * 0.1))
        }
    }
}
