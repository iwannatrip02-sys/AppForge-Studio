import Foundation
import simd

class MeasureEngine {
    
    func measureDistance(p1: SIMD3<Float>, p2: SIMD3<Float>) -> Float {
        return simd_distance(p1, p2)
    }
    
    func measureArea(mesh: Mesh) -> Float {
        var area: Float = 0
        for i in 0..<mesh.indices.count / 3 {
            let i0 = Int(mesh.indices[i * 3])
            let i1 = Int(mesh.indices[i * 3 + 1])
            let i2 = Int(mesh.indices[i * 3 + 2])
            let v0 = mesh.vertices[i0].position
            let v1 = mesh.vertices[i1].position
            let v2 = mesh.vertices[i2].position
            let u = v1 - v0
            let w = v2 - v0
            area += simd_length(simd_cross(u, w)) * 0.5
        }
        return area
    }
    
    func measureVolume(mesh: Mesh) -> Float {
        // Teorema de divergencia para volumen de malla cerrada
        var volume: Float = 0
        for i in 0..<mesh.indices.count / 3 {
            let i0 = Int(mesh.indices[i * 3])
            let i1 = Int(mesh.indices[i * 3 + 1])
            let i2 = Int(mesh.indices[i * 3 + 2])
            let v0 = mesh.vertices[i0].position
            let v1 = mesh.vertices[i1].position
            let v2 = mesh.vertices[i2].position
            let cross = simd_cross(v1 - v0, v2 - v0)
            volume += simd_dot(v0, cross) / 6.0
        }
        return abs(volume)
    }
}
