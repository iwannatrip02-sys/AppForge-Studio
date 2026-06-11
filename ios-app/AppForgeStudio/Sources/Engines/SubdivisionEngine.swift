import Foundation
import simd
import Metal
import OSLog

private let logger = Logger(subsystem: "com.appforgestudio", category: "SubdivisionEngine")

// MARK: - SubdivisionEngine
//
// ## Decision: Catmull-Clark (adapted for triangles) + Loop subdivision
//
// Catmull-Clark is designed for quad-dominant meshes. Our pipeline produces
// triangle meshes (from sculpt, CSG, and voxel remesh), so we offer TWO paths:
//
//  1. **Catmull-Clark (triangular adaptation)** — `subdivide(_:levels:)`
//     Splits each triangle into 3 quad-like faces using face points, edge points,
//     and vertex point adjustments. Produces 6× more triangles per level.
//     Good for: general-purpose smoothing when you want quads in the output.
//
//  2. **Loop subdivision** — `loopSubdivide(_:levels:)`
//     Designed specifically for triangle meshes. Splits each triangle into 4
//     sub-triangles (1→4 refinement). Preserves triangle topology.
//     Good for: sculpting workflows where triangle density must remain uniform.
//
// Zero-division guards: every division by valence or count is guarded.
// NaN prevention: edge lengths and cross products are checked before normalization.
//
@MainActor
class SubdivisionEngine: ObservableObject {
    @Published var isSubdividing = false
    @Published var progress: Float = 0

    private let device: MTLDevice?

    init(device: MTLDevice? = nil) {
        self.device = device
    }

    // MARK: - Catmull-Clark (triangular adaptation)

    /// Apply Catmull-Clark subdivision adapted for triangular meshes, `levels` times.
    func subdivide(_ mesh: Mesh, levels: Int = 1) -> Mesh {
        guard levels > 0, mesh.vertices.count >= 3, mesh.indices.count >= 3 else {
            return mesh
        }

        var currentMesh = mesh
        isSubdividing = true
        progress = 0

        for level in 0..<min(levels, 4) {
            currentMesh = subdivideOnceCatmullClark(currentMesh)
            progress = Float(level + 1) / Float(levels)
        }

        if let device = device {
            currentMesh.uploadToGPU(device: device)
        }

        isSubdividing = false
        progress = 1.0
        return currentMesh
    }

    // MARK: - Loop Subdivision

    /// Apply Loop subdivision (designed for triangle meshes), `levels` times.
    /// Each level replaces 1 triangle with 4 sub-triangles (1→4 refinement).
    func loopSubdivide(_ mesh: Mesh, levels: Int = 1) -> Mesh {
        guard levels > 0, mesh.vertices.count >= 3, mesh.indices.count >= 3 else {
            return mesh
        }

        var currentMesh = mesh
        isSubdividing = true
        progress = 0

        for level in 0..<min(levels, 4) {
            currentMesh = loopSubdivideOnce(currentMesh)
            progress = Float(level + 1) / Float(levels)
        }

        if let device = device {
            currentMesh.uploadToGPU(device: device)
        }

        isSubdividing = false
        progress = 1.0
        return currentMesh
    }

    // MARK: - Preview (smooth-only, no topology change)

    /// Smooth vertices by averaging neighbour positions without adding new geometry.
    /// Useful for quick preview. Does NOT change vertex count or index buffer.
    func previewSubdivision(_ mesh: Mesh, level: Int) -> Mesh {
        guard level > 0 else { return mesh }
        var preview = mesh
        for _ in 0..<min(level, 3) {
            preview = smoothVertices(preview)
        }
        return preview
    }

    // MARK: - Loop subdivision: one level

    private func loopSubdivideOnce(_ mesh: Mesh) -> Mesh {
        let vertices = mesh.vertices
        let indices = mesh.indices
        let vertexCount = vertices.count
        let triCount = indices.count / 3
        guard triCount > 0 else { return mesh }

        // --- Build adjacency ---
        // edge → list of (triangleIndex, oppositeVertexIndex)
        var edgeToTriangles: [UInt64: [(tri: Int, opposite: Int)]] = [:]
        // vertex → set of adjacent vertices
        var vertexNeighbors: [Set<Int>] = Array(repeating: [], count: vertexCount)

        for t in 0..<triCount {
            let i0 = Int(indices[t * 3])
            let i1 = Int(indices[t * 3 + 1])
            let i2 = Int(indices[t * 3 + 2])
            guard i0 < vertexCount, i1 < vertexCount, i2 < vertexCount else { continue }

            // Register edges with their opposite vertex
            let edges: [(Int, Int, Int)] = [(i0, i1, i2), (i1, i2, i0), (i2, i0, i1)]
            for (a, b, opp) in edges {
                let key = edgeKey(min(a, b), max(a, b))
                if edgeToTriangles[key] == nil {
                    edgeToTriangles[key] = []
                }
                edgeToTriangles[key]!.append((tri: t, opposite: opp))
            }

            // Build vertex adjacency
            vertexNeighbors[i0].insert(i1); vertexNeighbors[i0].insert(i2)
            vertexNeighbors[i1].insert(i0); vertexNeighbors[i1].insert(i2)
            vertexNeighbors[i2].insert(i0); vertexNeighbors[i2].insert(i1)
        }

        // --- 1. Compute new positions for original vertices ---
        var newVertexPositions: [SIMD3<Float>] = Array(repeating: .zero, count: vertexCount)
        for vi in 0..<vertexCount {
            let neighbors = vertexNeighbors[vi]
            let n = Float(neighbors.count)

            if n == 0 {
                newVertexPositions[vi] = vertices[vi].position
                continue
            }

            // Loop weight (classic formula, simplified)
            // beta = 1/n * (5/8 - (3/8 + 1/4 * cos(2π/n))^2)
            // This is approximated well by the piecewise formula:
            let beta: Float
            if neighbors.count == 3 {
                beta = 3.0 / 16.0
            } else {
                let nf = n
                let cosTerm = cos(2.0 * .pi / nf)
                let inner = 3.0 / 8.0 + 1.0 / 4.0 * cosTerm
                beta = 1.0 / nf * (5.0 / 8.0 - inner * inner)
            }

            var neighborSum = SIMD3<Float>.zero
            for nb in neighbors {
                neighborSum += vertices[nb].position
            }

            newVertexPositions[vi] = (1.0 - n * beta) * vertices[vi].position + beta * neighborSum
        }

        // --- 2. Compute edge points ---
        var edgePointIndex: [UInt64: Int] = [:]
        var newVertices: [Vertex] = []

        // Copy original vertices with updated positions
        for i in 0..<vertexCount {
            var v = vertices[i]
            v.position = newVertexPositions[i]
            newVertices.append(v)
        }

        // Create edge-point vertices
        for (key, tris) in edgeToTriangles {
            let a = Int(key >> 32)
            let b = Int(key & 0xFFFFFFFF)
            guard a < vertexCount, b < vertexCount else { continue }

            let edgePos: SIMD3<Float>
            if tris.count >= 2 {
                // Interior edge: Loop formula
                // 3/8 * (v0 + v1) + 1/8 * (v2 + v3)
                let v2 = vertices[tris[0].opposite].position
                let v3 = vertices[tris[1].opposite].position
                edgePos = 3.0/8.0 * (vertices[a].position + vertices[b].position)
                        + 1.0/8.0 * (v2 + v3)
            } else if tris.count == 1 {
                // Boundary edge: midpoint
                edgePos = 0.5 * (vertices[a].position + vertices[b].position)
            } else {
                // Degenerate: skip
                continue
            }

            edgePointIndex[key] = newVertices.count
            // Normal will be recomputed after topology is built
            newVertices.append(Vertex(position: edgePos, normal: .zero, uv: .zero))
        }

        // --- 3. Build new triangles ---
        // Each original triangle (v0, v1, v2) produces 4 sub-triangles:
        //   (v0, e01, e20), (v1, e12, e01), (v2, e20, e12), (e01, e12, e20)
        var newIndices: [UInt32] = []

        for t in 0..<triCount {
            let i0 = Int(indices[t * 3])
            let i1 = Int(indices[t * 3 + 1])
            let i2 = Int(indices[t * 3 + 2])
            guard i0 < vertexCount, i1 < vertexCount, i2 < vertexCount else { continue }

            let e01Key = edgeKey(min(i0, i1), max(i0, i1))
            let e12Key = edgeKey(min(i1, i2), max(i1, i2))
            let e20Key = edgeKey(min(i2, i0), max(i2, i0))

            guard let e01 = edgePointIndex[e01Key],
                  let e12 = edgePointIndex[e12Key],
                  let e20 = edgePointIndex[e20Key] else {
                continue
            }

            let v0 = UInt32(i0)
            let v1 = UInt32(i1)
            let v2 = UInt32(i2)
            let ep01 = UInt32(e01)
            let ep12 = UInt32(e12)
            let ep20 = UInt32(e20)

            // 4 sub-triangles (CCW winding assumed)
            newIndices.append(contentsOf: [v0, ep01, ep20])
            newIndices.append(contentsOf: [v1, ep12, ep01])
            newIndices.append(contentsOf: [v2, ep20, ep12])
            newIndices.append(contentsOf: [ep01, ep12, ep20])
        }

        // --- 4. Recalculate normals ---
        for i in 0..<newVertices.count {
            newVertices[i].normal = .zero
        }
        for i in stride(from: 0, to: newIndices.count, by: 3) {
            guard i + 2 < newIndices.count else { break }
            let i0 = Int(newIndices[i]), i1 = Int(newIndices[i+1]), i2 = Int(newIndices[i+2])
            guard i0 < newVertices.count, i1 < newVertices.count, i2 < newVertices.count else { continue }
            let e1 = newVertices[i1].position - newVertices[i0].position
            let e2 = newVertices[i2].position - newVertices[i0].position
            let n = simd_cross(e1, e2)
            let len = simd_length(n)
            if len > 1e-8 {
                let nn = n / len
                newVertices[i0].normal += nn
                newVertices[i1].normal += nn
                newVertices[i2].normal += nn
            }
        }
        for i in 0..<newVertices.count {
            let len = simd_length(newVertices[i].normal)
            if len > 1e-8 { newVertices[i].normal /= len }
        }

        return Mesh(vertices: newVertices, indices: newIndices)
    }

    // MARK: - Catmull-Clark (triangular adaptation): one level

    private func subdivideOnceCatmullClark(_ mesh: Mesh) -> Mesh {
        let vertices = mesh.vertices
        let indices = mesh.indices
        let vertexCount = vertices.count
        let faceCount = indices.count / 3

        guard faceCount > 0 else { return mesh }

        // Face vertex lists
        var faceVertices: [[Int]] = []
        for f in 0..<faceCount {
            let i0 = Int(indices[f * 3])
            let i1 = Int(indices[f * 3 + 1])
            let i2 = Int(indices[f * 3 + 2])
            faceVertices.append([i0, i1, i2])
        }

        // Edge → adjacent face indices
        var edgeToFaces: [UInt64: [Int]] = [:]
        for (fi, fv) in faceVertices.enumerated() {
            for j in 0..<3 {
                let a = fv[j]
                let b = fv[(j + 1) % 3]
                let key = edgeKey(min(a, b), max(a, b))
                if edgeToFaces[key] == nil { edgeToFaces[key] = [] }
                if !edgeToFaces[key]!.contains(fi) {
                    edgeToFaces[key]!.append(fi)
                }
            }
        }

        // Vertex → adjacent face indices
        var vertexFaces: [Int: [Int]] = [:]
        for (fi, fv) in faceVertices.enumerated() {
            for v in fv {
                if vertexFaces[v] == nil { vertexFaces[v] = [] }
                if !vertexFaces[v]!.contains(fi) {
                    vertexFaces[v]!.append(fi)
                }
            }
        }

        // 1. Face points — centroid of each face
        var facePoints: [SIMD3<Float>] = []
        for fv in faceVertices {
            let sum = vertices[fv[0]].position + vertices[fv[1]].position + vertices[fv[2]].position
            facePoints.append(sum / 3.0)
        }

        // 2. Edge points
        var edgePoints: [UInt64: SIMD3<Float>] = [:]
        for (key, faces) in edgeToFaces {
            let a = Int(key >> 32)
            let b = Int(key & 0xFFFFFFFF)
            guard a < vertexCount, b < vertexCount else { continue }
            let midpoint = (vertices[a].position + vertices[b].position) * 0.5

            if faces.count == 2 {
                // Interior edge: average of midpoint and adjacent face points
                let fp0 = facePoints[faces[0]]
                let fp1 = facePoints[faces[1]]
                edgePoints[key] = (midpoint + fp0 + fp1) / 3.0
            } else if faces.count == 1 {
                // Boundary edge: just the midpoint
                edgePoints[key] = midpoint
            } else if faces.count > 2 {
                // Non-manifold edge: use average of all adjacent face points
                var sum = midpoint
                for fi in faces { sum += facePoints[fi] }
                edgePoints[key] = sum / Float(faces.count + 1)
            } else {
                // No faces (shouldn't happen for valid edges)
                edgePoints[key] = midpoint
            }
        }

        // 3. Vertex points — Catmull-Clark formula
        var newVertexPositions: [SIMD3<Float>] = Array(repeating: .zero, count: vertexCount)
        for vi in 0..<vertexCount {
            guard let adjFaces = vertexFaces[vi], !adjFaces.isEmpty else {
                newVertexPositions[vi] = vertices[vi].position
                continue
            }

            let n = Float(adjFaces.count)

            // Q = average of adjacent face points
            var qSum = SIMD3<Float>.zero
            for fi in adjFaces { qSum += facePoints[fi] }
            let q = qSum / n

            // R = average of adjacent edge midpoints
            var rSum = SIMD3<Float>.zero
            var edgeCount: Float = 0
            for (key, _) in edgeToFaces {
                let a = Int(key >> 32)
                let b = Int(key & 0xFFFFFFFF)
                if a == vi || b == vi {
                    rSum += (vertices[a].position + vertices[b].position) * 0.5
                    edgeCount += 1
                }
            }
            let r = edgeCount > 0 ? rSum / edgeCount : vertices[vi].position

            let old = vertices[vi].position
            if n >= 3 {
                // Full Catmull-Clark: (Q + 2R + (n-3)*old) / n
                newVertexPositions[vi] = (q + 2.0 * r + (n - 3.0) * old) / n
            } else if n > 0 {
                // Low-valence fallback
                newVertexPositions[vi] = (q + 2.0 * r) / (n + 2.0)
            } else {
                newVertexPositions[vi] = old
            }
        }

        // 4. Build new mesh — 3 quad-like faces per original triangle
        var newVertices: [Vertex] = []
        var newIndices: [UInt32] = []

        // Original vertices with updated positions
        for i in 0..<vertexCount {
            var v = vertices[i]
            v.position = newVertexPositions[i]
            newVertices.append(v)
        }

        // Edge point vertices
        let edgePointStart = UInt32(newVertices.count)
        var edgePointIndex: [UInt64: UInt32] = [:]
        var epIdx = edgePointStart
        for (key, pos) in edgePoints {
            edgePointIndex[key] = epIdx
            newVertices.append(Vertex(position: pos, normal: .zero, uv: .zero))
            epIdx += 1
        }

        // Face point vertices
        let facePointStart = epIdx
        var facePointIndex: [Int: UInt32] = [:]
        for (fi, fp) in facePoints.enumerated() {
            facePointIndex[fi] = facePointStart + UInt32(fi)
            newVertices.append(Vertex(position: fp, normal: .zero, uv: .zero))
        }

        // Create 3 quad-like faces per triangle (each split into 2 tris)
        for (fi, fv) in faceVertices.enumerated() {
            let v0 = UInt32(fv[0])
            let v1 = UInt32(fv[1])
            let v2 = UInt32(fv[2])
            guard let fp = facePointIndex[fi] else { continue }

            let e01Key = edgeKey(min(fv[0], fv[1]), max(fv[0], fv[1]))
            let e12Key = edgeKey(min(fv[1], fv[2]), max(fv[1], fv[2]))
            let e20Key = edgeKey(min(fv[2], fv[0]), max(fv[2], fv[0]))

            guard let e01 = edgePointIndex[e01Key],
                  let e12 = edgePointIndex[e12Key],
                  let e20 = edgePointIndex[e20Key] else {
                continue
            }

            // Face 1: v0–e01–fp–e20 (2 triangles)
            newIndices.append(contentsOf: [v0, e01, fp, v0, fp, e20])
            // Face 2: v1–e12–fp–e01
            newIndices.append(contentsOf: [v1, e12, fp, v1, fp, e01])
            // Face 3: v2–e20–fp–e12
            newIndices.append(contentsOf: [v2, e20, fp, v2, fp, e12])
        }

        // Recalculate normals
        for i in 0..<newVertices.count {
            newVertices[i].normal = estimateNormalFromIndices(
                vertexIdx: i, vertices: newVertices, indices: newIndices
            )
        }

        return Mesh(vertices: newVertices, indices: newIndices)
    }

    // MARK: - Smooth only (no topology change)

    /// Smooth vertices using neighbour averaging. FIXED: removed dead-edge guard
    /// that was checking `guard let neighbors = edgeMap[edgeKey(vi, vi)]`
    /// which never matched (a self-loop edge key).
    private func smoothVertices(_ mesh: Mesh) -> Mesh {
        var newVertices = mesh.vertices
        let vertexCount = newVertices.count

        // Build neighbor adjacency from face indices
        var neighbors: [Set<Int>] = Array(repeating: [], count: vertexCount)
        for i in stride(from: 0, to: mesh.indices.count, by: 3) {
            guard i + 2 < mesh.indices.count else { break }
            let i0 = Int(mesh.indices[i])
            let i1 = Int(mesh.indices[i+1])
            let i2 = Int(mesh.indices[i+2])
            guard i0 < vertexCount, i1 < vertexCount, i2 < vertexCount else { continue }
            neighbors[i0].insert(i1); neighbors[i0].insert(i2)
            neighbors[i1].insert(i0); neighbors[i1].insert(i2)
            neighbors[i2].insert(i0); neighbors[i2].insert(i1)
        }

        // Average each vertex with its neighbors (50/50 blend for preview smooth)
        for vi in 0..<vertexCount {
            let nb = neighbors[vi]
            guard !nb.isEmpty else { continue }
            var sum = SIMD3<Float>.zero
            for n in nb { sum += mesh.vertices[n].position }
            let avg = sum / Float(nb.count)
            newVertices[vi].position = mesh.vertices[vi].position * 0.5 + avg * 0.5
        }

        // Recalculate normals after smoothing
        var result = mesh
        result.vertices = newVertices
        // Use the Mesh's own recalculateNormals via a temp var + applying morphs trick
        // Better: recalculate normals directly
        for i in 0..<result.vertices.count { result.vertices[i].normal = .zero }
        for i in stride(from: 0, to: result.indices.count, by: 3) {
            guard i + 2 < result.indices.count else { break }
            let i0 = Int(result.indices[i]), i1 = Int(result.indices[i+1]), i2 = Int(result.indices[i+2])
            guard i0 < result.vertices.count, i1 < result.vertices.count, i2 < result.vertices.count else { continue }
            let e1 = result.vertices[i1].position - result.vertices[i0].position
            let e2 = result.vertices[i2].position - result.vertices[i0].position
            let n = simd_cross(e1, e2)
            let len = simd_length(n)
            if len > 1e-8 {
                let nn = n / len
                result.vertices[i0].normal += nn
                result.vertices[i1].normal += nn
                result.vertices[i2].normal += nn
            }
        }
        for i in 0..<result.vertices.count {
            let len = simd_length(result.vertices[i].normal)
            if len > 1e-8 { result.vertices[i].normal /= len }
        }
        return result
    }

    // MARK: - Helpers

    private func edgeKey(_ a: Int, _ b: Int) -> UInt64 {
        let minVal = UInt64(min(a, b))
        let maxVal = UInt64(max(a, b))
        return (minVal << 32) | maxVal
    }

    private func addEdge(_ map: inout [UInt64: [Int]], a: Int, b: Int, faceIdx: Int) {
        let key = edgeKey(a, b)
        if map[key] == nil { map[key] = [] }
        if !map[key]!.contains(faceIdx) {
            map[key]!.append(faceIdx)
        }
    }

    private func estimateNormal(at vi: Int, mesh: Mesh, edgeMap: [UInt64: [Int]]) -> SIMD3<Float> {
        guard vi < mesh.vertices.count else { return .zero }
        var normal = SIMD3<Float>.zero
        var count = 0
        for i in stride(from: 0, to: mesh.indices.count, by: 3) {
            guard i + 2 < mesh.indices.count else { break }
            let i0 = Int(mesh.indices[i])
            let i1 = Int(mesh.indices[i+1])
            let i2 = Int(mesh.indices[i+2])
            if i0 == vi || i1 == vi || i2 == vi {
                let v0 = mesh.vertices[i0].position
                let v1 = mesh.vertices[i1].position
                let v2 = mesh.vertices[i2].position
                let edge1 = v1 - v0
                let edge2 = v2 - v0
                let faceNormal = simd_cross(edge1, edge2)
                let len = simd_length(faceNormal)
                if len > 1e-8 {
                    normal += faceNormal / len
                    count += 1
                }
            }
        }
        guard count > 0 else { return .zero }
        return simd_normalize(normal / Float(count))
    }

    private func estimateNormalFromIndices(vertexIdx: Int, vertices: [Vertex], indices: [UInt32]) -> SIMD3<Float> {
        var normal = SIMD3<Float>.zero
        var count = 0
        let ui = UInt32(vertexIdx)
        for i in stride(from: 0, to: indices.count, by: 3) {
            guard i + 2 < indices.count else { break }
            let i0 = indices[i]
            let i1 = indices[i+1]
            let i2 = indices[i+2]
            if i0 == ui || i1 == ui || i2 == ui {
                let v0 = vertices[Int(i0)].position
                let v1 = vertices[Int(i1)].position
                let v2 = vertices[Int(i2)].position
                let edge1 = v1 - v0
                let edge2 = v2 - v0
                let faceNormal = simd_cross(edge1, edge2)
                let len = simd_length(faceNormal)
                if len > 1e-8 {
                    normal += faceNormal / len
                    count += 1
                }
            }
        }
        guard count > 0 else { return .zero }
        return simd_normalize(normal / Float(count))
    }
}
