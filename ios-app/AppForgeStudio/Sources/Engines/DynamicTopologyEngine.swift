import Foundation
import simd
import OSLog

private let logger = Logger(subsystem: "com.appforgestudio", category: "DynamicTopo")

// MARK: - RemeshTrigger

/// Callback invoked when the dynamic topology engine produces a remesh event.
/// SculptEngine or other consumers can hook into this to refresh GPU buffers.
struct RemeshTrigger {
    /// The mesh that was modified.
    let mesh: Mesh
    /// Indices of vertices that were added, moved, or removed.
    let affectedVertexIndices: Set<Int>
    /// True if vertex count changed (requires buffer reallocation).
    let topologyChanged: Bool
}

/// Protocol for objects that want to react to dynamic topology events.
protocol DynamicTopologyDelegate: AnyObject {
    func dynamicTopologyDidRemesh(_ trigger: RemeshTrigger)
}

// MARK: - DynamicTopologyEngine

/// Dynamic topology: subdivide near the brush, decimate far from it.
/// Enables Nomad Sculpt-style variable-resolution sculpting on iPad.
///
/// Uses two complementary metrics:
///   - **Edge-length based** (fast, topology-aware): split long edges, collapse short ones.
///   - **Face-area based** (quality-focused): split large-area faces, collapse tiny ones.
///
/// Both metrics are applied in sequence during each `apply()` call.
///
/// Integration with SculptEngine:
///   Set `delegate` to receive `RemeshTrigger` events. The delegate is responsible
///   for uploading modified buffers to the GPU without a full scene rebuild.
@MainActor
final class DynamicTopologyEngine {

    // MARK: - Edge-length thresholds

    /// Maximum edge length before subdivision triggers (world units).
    var maxEdgeLength: Float = 0.02
    /// Minimum edge length before collapse triggers.
    var minEdgeLength: Float = 0.002

    // MARK: - Face-area thresholds

    /// Maximum face area before subdivision triggers (world units²).
    /// Default: area of equilateral triangle with side = maxEdgeLength.
    var maxFaceArea: Float = 0.0002
    /// Minimum face area before collapse triggers.
    var minFaceArea: Float = 0.000002

    /// How many rings of neighbors to check from brush center.
    var influenceRings: Int = 3

    /// Delegate notified on every remesh event (optional, for SculptEngine integration).
    weak var delegate: DynamicTopologyDelegate?

    // MARK: - Main entry point

    /// Apply dynamic topology to a mesh around a brush point.
    /// Returns the modified mesh and a set of affected vertex indices.
    @discardableResult
    func apply(to mesh: inout Mesh, at point: SIMD3<Float>, radius: Float) -> RemeshTrigger {
        var allAffected = Set<Int>()
        let edges = buildEdgeMap(indices: mesh.indices)
        let initialVertexCount = mesh.vertices.count
        let initialTriCount = mesh.indices.count / 3

        // Phase 1: Edge-length-based split (near brush)
        let splitCount = splitLongEdges(&mesh, edges: edges, center: point, radius: radius)
        if splitCount > 0 {
            logger.debug("[DynamicTopo] split \(splitCount) edges (edge-length metric) at radius \(radius)")
        }

        // Phase 2: Face-area-based split (near brush)
        let faSplitCount = splitLargeFaces(&mesh, center: point, radius: radius)
        if faSplitCount > 0 {
            logger.debug("[DynamicTopo] split \(faSplitCount) faces (face-area metric)")
        }

        // Phase 3: Edge-length-based collapse (far from brush)
        let collapseCount = collapseShortEdges(&mesh, edges: edges, center: point, radius: radius * 2)
        if collapseCount > 0 {
            logger.debug("[DynamicTopo] collapsed \(collapseCount) edges (edge-length metric)")
        }

        // Phase 4: Face-area-based collapse (far from brush)
        let faCollapseCount = collapseSmallFaces(&mesh, center: point, radius: radius * 2)
        if faCollapseCount > 0 {
            logger.debug("[DynamicTopo] collapsed \(faCollapseCount) faces (face-area metric)")
        }

        // Mark affected vertices (those near the brush)
        for (i, v) in mesh.vertices.enumerated() {
            if simd_distance(v.position, point) < radius * 1.5 {
                allAffected.insert(i)
            }
        }

        let topologyChanged = (mesh.vertices.count != initialVertexCount)
                           || (mesh.indices.count / 3 != initialTriCount)

        let trigger = RemeshTrigger(
            mesh: mesh,
            affectedVertexIndices: allAffected,
            topologyChanged: topologyChanged
        )

        delegate?.dynamicTopologyDidRemesh(trigger)
        return trigger
    }

    // MARK: - Face area utility

    private func faceArea(_ mesh: Mesh, triIndex: Int) -> Float {
        let base = triIndex * 3
        guard base + 2 < mesh.indices.count else { return 0 }
        let i0 = Int(mesh.indices[base])
        let i1 = Int(mesh.indices[base + 1])
        let i2 = Int(mesh.indices[base + 2])
        guard i0 < mesh.vertices.count, i1 < mesh.vertices.count, i2 < mesh.vertices.count else { return 0 }
        let e1 = mesh.vertices[i1].position - mesh.vertices[i0].position
        let e2 = mesh.vertices[i2].position - mesh.vertices[i0].position
        return simd_length(simd_cross(e1, e2)) * 0.5
    }

    private func faceCentroid(_ mesh: Mesh, triIndex: Int) -> SIMD3<Float> {
        let base = triIndex * 3
        guard base + 2 < mesh.indices.count else { return .zero }
        let i0 = Int(mesh.indices[base])
        let i1 = Int(mesh.indices[base + 1])
        let i2 = Int(mesh.indices[base + 2])
        guard i0 < mesh.vertices.count, i1 < mesh.vertices.count, i2 < mesh.vertices.count else { return .zero }
        return (mesh.vertices[i0].position + mesh.vertices[i1].position + mesh.vertices[i2].position) / 3.0
    }

    /// Longest edge of a face (used for subdivision point placement).
    private func longestEdgeOfFace(_ mesh: Mesh, triIndex: Int) -> (a: Int, b: Int, length: Float)? {
        let base = triIndex * 3
        guard base + 2 < mesh.indices.count else { return nil }
        let i0 = Int(mesh.indices[base])
        let i1 = Int(mesh.indices[base + 1])
        let i2 = Int(mesh.indices[base + 2])
        guard i0 < mesh.vertices.count, i1 < mesh.vertices.count, i2 < mesh.vertices.count else { return nil }
        let edges: [(Int, Int)] = [(i0, i1), (i1, i2), (i2, i0)]
        var best: (Int, Int, Float) = (i0, i1, 0)
        for (a, b) in edges {
            let len = simd_distance(mesh.vertices[a].position, mesh.vertices[b].position)
            if len > best.2 { best = (a, b, len) }
        }
        return (best.0, best.1, best.2)
    }

    // MARK: - Edge Utilities

    struct Edge: Hashable {
        let a: UInt32, b: UInt32
        init(_ a: UInt32, _ b: UInt32) { self.a = min(a, b); self.b = max(a, b) }
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

    // MARK: - Edge Split (subdivision by edge length)

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

                // Split all triangles containing this edge
                var t = 0
                while t < mesh.indices.count {
                    guard t + 2 < mesh.indices.count else { break }
                    let t0 = mesh.indices[t], t1 = mesh.indices[t+1], t2 = mesh.indices[t+2]
                    let matched: (UInt32, UInt32, UInt32)? = {
                        if (t0 == edge.a && t1 == edge.b) || (t1 == edge.a && t0 == edge.b) {
                            return (edge.a, edge.b, t2)  // opposite = t2
                        }
                        if (t1 == edge.a && t2 == edge.b) || (t2 == edge.a && t1 == edge.b) {
                            return (edge.a, edge.b, t0)  // opposite = t0
                        }
                        if (t2 == edge.a && t0 == edge.b) || (t0 == edge.a && t2 == edge.b) {
                            return (edge.a, edge.b, t1)  // opposite = t1
                        }
                        return nil
                    }()

                    if let (ea, eb, opposite) = matched {
                        // Replace with 2 new triangles
                        mesh.indices[t] = ea
                        mesh.indices[t+1] = newIdx
                        mesh.indices[t+2] = opposite
                        mesh.indices.append(contentsOf: [newIdx, eb, opposite])
                        count += 1
                    }
                    t += 3
                }
            }
        }
        return count
    }

    // MARK: - Face Split (subdivision by face area)

    /// Subdivides faces whose area exceeds `maxFaceArea` and whose centroid
    /// is within `radius` of the brush center.
    private func splitLargeFaces(_ mesh: inout Mesh, center: SIMD3<Float>, radius: Float) -> Int {
        var count = 0
        let triCount = mesh.indices.count / 3

        var t = 0
        while t < triCount {
            let area = faceArea(mesh, triIndex: t)
            let centroid = faceCentroid(mesh, triIndex: t)
            let dist = simd_distance(centroid, center)

            if dist < radius && area > maxFaceArea {
                guard let longest = longestEdgeOfFace(mesh, triIndex: t),
                      longest.length > 1e-8 else {
                    t += 1
                    continue
                }

                let a = longest.a, b = longest.b
                let mid = (mesh.vertices[a].position + mesh.vertices[b].position) * 0.5
                let midNormal = simd_normalize(mesh.vertices[a].normal + mesh.vertices[b].normal)
                mesh.vertices.append(Vertex(position: mid, normal: midNormal))
                let newIdx = UInt32(mesh.vertices.count - 1)

                // Find and split the triangle at the longest edge
                let base = t * 3
                let t0 = mesh.indices[base], t1 = mesh.indices[base+1], t2 = mesh.indices[base+2]
                // Find which edge is the longest and find the opposite vertex
                let edges: [(UInt32, UInt32, UInt32)] = [(t0, t1, t2), (t1, t2, t0), (t2, t0, t1)]
                var found = false
                for (ea, eb, opposite) in edges {
                    if (Int(ea) == a && Int(eb) == b) || (Int(eb) == a && Int(ea) == b) {
                        // Split this triangle at the matched edge
                        mesh.indices[base] = ea
                        mesh.indices[base+1] = newIdx
                        mesh.indices[base+2] = opposite
                        mesh.indices.append(contentsOf: [newIdx, eb, opposite])
                        found = true
                        count += 1
                        break
                    }
                }
                if !found {
                    // Fallback: split at the first edge
                    mesh.indices[base] = t0
                    mesh.indices[base+1] = newIdx
                    mesh.indices[base+2] = t2
                    mesh.indices.append(contentsOf: [newIdx, t1, t2])
                    count += 1
                }
            }
            t += 1
        }
        return count
    }

    // MARK: - Edge Collapse (decimation by edge length)

    private func collapseShortEdges(_ mesh: inout Mesh, edges: [Edge: Float], center: SIMD3<Float>, radius: Float) -> Int {
        var count = 0
        for edge in edges.keys {
            let a = Int(edge.a), b = Int(edge.b)
            guard a < mesh.vertices.count, b < mesh.vertices.count else { continue }
            let va = mesh.vertices[a], vb = mesh.vertices[b]
            let mid = (va.position + vb.position) * 0.5
            let dist = simd_distance(mid, center)
            let edgeLen = simd_distance(va.position, vb.position)

            if dist > radius && edgeLen < minEdgeLength && edgeLen > 0 {
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
        // Remove degenerate triangles (any two indices equal)
        mesh.indices = mesh.indices.enumerated().compactMap { idx, val in
            let triStart = (idx / 3) * 3
            guard triStart + 2 < mesh.indices.count else { return val }
            let i0 = mesh.indices[triStart]
            let i1 = mesh.indices[triStart + 1]
            let i2 = mesh.indices[triStart + 2]
            if i0 == i1 || i1 == i2 || i2 == i0 { return nil }
            return val
        }
        return count
    }

    // MARK: - Face Collapse (decimation by face area)

    /// Collapses faces whose area falls below `minFaceArea` and whose centroid
    /// is farther than `radius` from the brush center.
    private func collapseSmallFaces(_ mesh: inout Mesh, center: SIMD3<Float>, radius: Float) -> Int {
        var count = 0
        let triCount = mesh.indices.count / 3

        // Mark faces to remove
        var facesToRemove = Set<Int>()
        for t in 0..<triCount {
            let area = faceArea(mesh, triIndex: t)
            let centroid = faceCentroid(mesh, triIndex: t)
            let dist = simd_distance(centroid, center)

            if dist > radius && area < minFaceArea && area > 1e-10 {
                facesToRemove.insert(t)
            }
        }

        guard !facesToRemove.isEmpty else { return 0 }

        // Build new index array excluding collapsed faces
        var newIndices: [UInt32] = []
        for t in 0..<triCount {
            if facesToRemove.contains(t) {
                count += 1
                continue
            }
            let base = t * 3
            guard base + 2 < mesh.indices.count else { continue }
            newIndices.append(contentsOf: [
                mesh.indices[base],
                mesh.indices[base + 1],
                mesh.indices[base + 2]
            ])
        }
        mesh.indices = newIndices
        return count
    }
}


