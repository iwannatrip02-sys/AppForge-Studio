import Foundation
import simd

/// Mallas procedurales del gizmo de transformación (ÁREA 1b): una flecha por
/// eje (cilindro + cono), construida en coordenadas de MUNDO en el centro del
/// cuerpo seleccionado. Los overlays "__gizmo*" no son tocables por el picker;
/// la interacción se resuelve en pantalla (MetalView.gizmoAxisHit).
enum GizmoBuilder {

    /// Flecha desde `center` a lo largo de `axis` (unitario).
    static func arrowMesh(center: SIMD3<Float>, axis: SIMD3<Float>,
                          length: Float, shaftRadius: Float = 0.018,
                          segments: Int = 10) -> Mesh {
        let dir = simd_normalize(axis)
        let ref: SIMD3<Float> = abs(dir.x) < 0.9 ? SIMD3<Float>(1, 0, 0) : SIMD3<Float>(0, 1, 0)
        let u = simd_normalize(simd_cross(dir, ref))
        let v = simd_normalize(simd_cross(dir, u))

        var vertices: [Vertex] = []
        var indices: [UInt32] = []

        let shaftEnd = center + dir * (length * 0.72)
        let tip = center + dir * length
        let headRadius = shaftRadius * 3.2

        // Anillos del cilindro (base y fin del shaft)
        func ring(at p: SIMD3<Float>, radius: Float) -> [Int] {
            var ids: [Int] = []
            for k in 0..<segments {
                let t = Float(k) / Float(segments) * 2 * .pi
                let offset = u * cos(t) * radius + v * sin(t) * radius
                ids.append(vertices.count)
                vertices.append(Vertex(position: p + offset,
                                       normal: simd_normalize(offset), uv: .zero))
            }
            return ids
        }

        let base = ring(at: center, radius: shaftRadius)
        let top = ring(at: shaftEnd, radius: shaftRadius)
        for k in 0..<segments {
            let k2 = (k + 1) % segments
            indices.append(contentsOf: [UInt32(base[k]), UInt32(top[k]), UInt32(base[k2]),
                                        UInt32(base[k2]), UInt32(top[k]), UInt32(top[k2])])
        }

        // Cono de la punta
        let headBase = ring(at: shaftEnd, radius: headRadius)
        let tipIdx = vertices.count
        vertices.append(Vertex(position: tip, normal: dir, uv: .zero))
        for k in 0..<segments {
            let k2 = (k + 1) % segments
            indices.append(contentsOf: [UInt32(headBase[k]), UInt32(tipIdx), UInt32(headBase[k2])])
        }

        return Mesh(vertices: vertices, indices: indices)
    }
}
