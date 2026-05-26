import Foundation
import simd
import OSLog

private let logger = Logger(subsystem: "com.appforgestudio", category: "ChamferEngine")

class ChamferEngine {

    func computeChamfer(edges: [(Int, Int)], distance: Float, mesh: inout Mesh, segments: Int = 2) -> Bool {
        guard !edges.isEmpty, distance > 0, segments > 0 else { return false }

        var newVertices = mesh.vertices
        var newIndices = [UInt32]()
        let originalCount = mesh.vertices.count
        var edgeGridMap = [Int: [[Int]]]()
        var edgeFaceMap = [Int: (n1: SIMD3<Float>, n2: SIMD3<Float>, c1: Int, c2: Int)]()
        var removedTriangles = Set<Int>()

        // 1. Find adjacent faces for each edge
        for (a, b) in edges {
            let key = min(a, b) * originalCount + max(a, b)
            guard edgeFaceMap[key] == nil else { continue }

            var normals = [SIMD3<Float>]()
            var thirds = [Int]()

            for i in stride(from: 0, to: mesh.indices.count, by: 3) {
                let i0 = Int(mesh.indices[i])
                let i1 = Int(mesh.indices[i+1])
                let i2 = Int(mesh.indices[i+2])
                guard Set([i0, i1, i2]).isSuperset(of: [a, b]) else { continue }

                let p0 = mesh.vertices[i0].position
                let p1 = mesh.vertices[i1].position
                let p2 = mesh.vertices[i2].position
                normals.append(normalize(cross(p1 - p0, p2 - p0)))
                thirds.append([i0, i1, i2].first { $0 != a && $0 != b } ?? i0)
                removedTriangles.insert(i)
            }

            guard normals.count >= 2 else {
                logger.warning("Chamfer: edge (\(a),\(b)) has \(normals.count) face(s), skip")
                continue
            }

            edgeFaceMap[key] = (normals[0], normals[1], thirds[0], thirds[1])
        }

        guard !edgeFaceMap.isEmpty else { return false }

        // 2. Generate chamfer geometry (linear cut)
        for (a, b) in edges {
            let key = min(a, b) * originalCount + max(a, b)
            guard let fm = edgeFaceMap[key], edgeGridMap[key] == nil,
                  a < mesh.vertices.count, b < mesh.vertices.count else { continue }

            let posA = mesh.vertices[a].position
            let posB = mesh.vertices[b].position
            let edgeLen = distance(posA, posB)
            guard edgeLen > 1e-6 else { continue }
            let edgeDir = (posB - posA) / edgeLen
            let midEdge = (posA + posB) * 0.5

            // Perpendicular directions from edge into each face
            var D1 = normalize(cross(fm.n1, edgeDir))
            if dot(D1, mesh.vertices[fm.c1].position - midEdge) < 0 { D1 = -D1 }

            var D2 = normalize(cross(fm.n2, edgeDir))
            if dot(D2, mesh.vertices[fm.c2].position - midEdge) < 0 { D2 = -D2 }

            // Chamfer: linear interpolation between D1 and D2 at distance offset
            let offset1 = distance * D1
            let offset2 = distance * D2

            var grid = [[Int]]()

            for i in 0...segments {
                let t = Float(i) / Float(segments)
                let edgePos = simd_mix(posA, posB, t)
                var row = [Int]()

                for j in 0...segments {
                    let s = Float(j) / Float(segments)
                    // Linear interpolation from face 1 offset to face 2 offset
                    let offset = simd_mix(offset1, offset2, s)
                    let pos = edgePos + offset
                    // Normal: blend of face normals
                    let normal = normalize(simd_mix(fm.n1, fm.n2, s))
                    let v = Vertex(position: pos, normal: normal, uv: .zero)
                    row.append(newVertices.count)
                    newVertices.append(v)
                }
                grid.append(row)
            }
            edgeGridMap[key] = grid
        }

        // 3. Stitch chamfer surface triangles
        for (key, grid) in edgeGridMap {
            for i in 0..<segments {
                for j in 0..<segments {
                    let a0 = grid[i][j]
                    let a1 = grid[i][j+1]
                    let b0 = grid[i+1][j]
                    let b1 = grid[i+1][j+1]
                    newIndices.append(contentsOf: [UInt32(a0), UInt32(a1), UInt32(b1)])
                    newIndices.append(contentsOf: [UInt32(a0), UInt32(b1), UInt32(b0)])
                }
            }

            // Gap-fill triangles
            guard let fm = edgeFaceMap[key] else { continue }

            let nCount = max(originalCount, 1)
            let edgeMin = key / nCount
            let edgeMax = key % nCount
            let a = edges.first(where: { min($0.0, $0.1) == edgeMin && max($0.0, $0.1) == edgeMax })?.0 ?? edgeMin
            let b = edges.first(where: { min($0.0, $0.1) == edgeMin && max($0.0, $0.1) == edgeMax })?.1 ?? edgeMax

            let c1 = fm.c1
            let c2 = fm.c2

            // Face 1 fan
            newIndices.append(contentsOf: [UInt32(c1), UInt32(a), UInt32(grid[0][0])])
            for i in 0..<segments {
                newIndices.append(contentsOf: [UInt32(c1), UInt32(grid[i][0]), UInt32(grid[i+1][0])])
            }
            newIndices.append(contentsOf: [UInt32(c1), UInt32(grid[segments][0]), UInt32(b)])

            // Face 2 fan
            newIndices.append(contentsOf: [UInt32(c2), UInt32(grid[0][segments]), UInt32(a)])
            for i in 0..<segments {
                newIndices.append(contentsOf: [UInt32(c2), UInt32(grid[i+1][segments]), UInt32(grid[i][segments])])
            }
            newIndices.append(contentsOf: [UInt32(c2), UInt32(b), UInt32(grid[segments][segments])])
        }

        // 4. Copy unaffected triangles
        for i in stride(from: 0, to: mesh.indices.count, by: 3) {
            guard !removedTriangles.contains(i) else { continue }
            newIndices.append(contentsOf: [mesh.indices[i], mesh.indices[i+1], mesh.indices[i+2]])
        }

        mesh = Mesh(vertices: newVertices, indices: newIndices)
        return true
    }
}
