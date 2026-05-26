import Foundation
import simd
import OSLog

private let logger = Logger(subsystem: "com.appforgestudio", category: "DynamicTopo")

/// Dynamic topology: subdivide near the brush, decimate far from it.
/// Enables Nomad Sculpt-style variable-resolution sculpting on iPad.
@MainActor
final class DynamicTopologyEngine {
    
    /// Maximum edge length before subdivision triggers (world units)
    var maxEdgeLength: Float = 0.02
    /// Minimum edge length before collapse triggers
    var minEdgeLength: Float = 0.002
    /// How many rings of neighbors to check from brush center
    var influenceRings: Int = 3
    
    // MARK: - Main entry point
    
    /// Apply dynamic topology to a mesh around a brush point.
    /// Returns the modified mesh and a set of affected vertex indices.
    func apply(to mesh: inout Mesh, at point: SIMD3<Float>, radius: Float) -> Set<Int> {
        var affected = Set<Int>()
        let edges = buildEdgeMap(indices: mesh.indices)
        
        // Phase 1: Split long edges near brush
        let splitCount = splitLongEdges(&mesh, edges: edges, center: point, radius: radius)
        if splitCount > 0 {
            logger.debug("[DynamicTopo] split \(splitCount) edges at radius \(radius)")
        }
        
        // Phase 2: Collapse short edges far from brush
        let collapseCount = collapseShortEdges(&mesh, edges: edges, center: point, radius: radius * 2)
        if collapseCount > 0 {
            logger.debug("[DynamicTopo] collapsed \(collapseCount) edges")
        }
        
        // Mark affected vertices (those near the brush)
        for (i, v) in mesh.vertices.enumerated() {
            if simd_distance(v.position, point) < radius * 1.5 {
                affected.insert(i)
            }
        }
        
        return affected
    }
    
    // MARK: - Edge Utilities
    
    struct Edge: Hashable {
        let a: UInt32, b: UInt32
        init(_ a: UInt32, _ b: UInt32) { self.a = min(a,b); self.b = max(a,b) }
    }
    
    private func buildEdgeMap(indices: [UInt32]) -> [Edge: Float] {
        var map: [Edge: Float] = [:]
        for i in stride(from: 0, to: indices.count, by: 3) {
            guard i + 2 < indices.count else { break }
            let i0 = indices[i], i1 = indices[i+1], i2 = indices[i+2]
            map[Edge(i0, i1)] = 0
            map[Edge(i1, i2)] = 0
            map[Edge(i2, i0)] = 0
        }
        return map
    }
    
    // MARK: - Edge Split (subdivision)
    
    private func splitLongEdges(_ mesh: inout Mesh, edges: [Edge: Float], center: SIMD3<Float>, radius: Float) -> Int {
        var count = 0
        for edge in edges.keys {
            let a = Int(edge.a), b = Int(edge.b)
            guard a < mesh.vertices.count, b < mesh.vertices.count else { continue }
            let va = mesh.vertices[a], vb = mesh.vertices[b]
            let mid = (va.position + vb.position) * 0.5
            let dist = simd_distance(mid, center)
            let edgeLen = simd_distance(va.position, vb.position)
            
            if dist < radius && edgeLen > maxEdgeLength {
                let midVertex = Vertex(
                    position: mid,
                    normal: simd_normalize(va.normal + vb.normal)
                )
                mesh.vertices.append(midVertex)
                let newIdx = UInt32(mesh.vertices.count - 1)
                
                // Replace edge in all triangles
                for t in stride(from: 0, to: mesh.indices.count, by: 3) {
                    guard t + 2 < mesh.indices.count else { break }
                    let t0 = mesh.indices[t], t1 = mesh.indices[t+1], t2 = mesh.indices[t+2]
                    let tris: [(UInt32, UInt32, UInt32)] = [
                        (edge.a, edge.b, t0), (edge.a, edge.b, t1), (edge.a, edge.b, t2)
                    ]
                    for (ea, eb, opposite) in tris {
                        if (t0 == ea && t1 == eb) || (t1 == ea && t0 == eb) {
                            // Triangle uses this edge: split it into 2 triangles
                            mesh.indices[t] = ea
                            mesh.indices[t+1] = newIdx
                            mesh.indices[t+2] = opposite
                            // Add second triangle
                            mesh.indices.append(contentsOf: [newIdx, eb, opposite])
                            count += 1
                            break
                        } else if (t1 == ea && t2 == eb) || (t2 == ea && t1 == eb) {
                            mesh.indices[t] = opposite
                            mesh.indices[t+1] = ea
                            mesh.indices[t+2] = newIdx
                            mesh.indices.append(contentsOf: [newIdx, eb, opposite])
                            count += 1
                            break
                        } else if (t2 == ea && t0 == eb) || (t0 == ea && t2 == eb) {
                            mesh.indices[t] = newIdx
                            mesh.indices[t+1] = eb
                            mesh.indices[t+2] = opposite
                            mesh.indices.append(contentsOf: [newIdx, opposite, ea])
                            count += 1
                            break
                        }
                    }
                }
            }
        }
        return count
    }
    
    // MARK: - Edge Collapse (decimation)
    
    private func collapseShortEdges(_ mesh: inout Mesh, edges: [Edge: Float], center: SIMD3<Float>, radius: Float) -> Int {
        var count = 0
        for edge in edges.keys {
            let a = Int(edge.a), b = Int(edge.b)
            guard a < mesh.vertices.count, b < mesh.vertices.count else { continue }
            let va = mesh.vertices[a], vb = mesh.vertices[b]
            let mid = (va.position + vb.position) * 0.5
            let dist = simd_distance(mid, center)
            let edgeLen = simd_distance(va.position, vb.position)
            
            if dist > radius && edgeLen < minEdgeLength {
                let collapsed = Vertex(
                    position: mid,
                    normal: simd_normalize(va.normal + vb.normal)
                )
                mesh.vertices[a] = collapsed
                // Redirect indices from b to a
                for j in 0..<mesh.indices.count {
                    if mesh.indices[j] == edge.b { mesh.indices[j] = edge.a }
                }
                count += 1
            }
        }
        // Remove degenerate triangles
        mesh.indices = mesh.indices.enumerated().compactMap { t, _ in
            (t % 3 == 2) && (
                mesh.indices[t-2] == mesh.indices[t-1] ||
                mesh.indices[t-1] == mesh.indices[t] ||
                mesh.indices[t] == mesh.indices[t-2]
            ) ? nil : mesh.indices[t]
        }
        return count
    }
}
