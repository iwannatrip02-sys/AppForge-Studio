import Foundation
import simd
import OSLog

private let logger = Logger(subsystem: "com.appforgestudio", category: "FilletEngine")

class FilletEngine {

    func computeFillet(edges: [(Int, Int)], radius: Float, mesh: inout Mesh, segments: Int = 8) -> Bool {
        guard !edges.isEmpty, radius > 0, segments > 1 else { return false }

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
                logger.warning("Edge (\(a),\(b)) has \(normals.count) face(s), skip")
                continue
            }

            edgeFaceMap[key] = (normals[0], normals[1], thirds[0], thirds[1])
        }

        guard !edgeFaceMap.isEmpty else { return false }

        // 2. Generate fillet grid for each edge using Catmull-Rom spline
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

            // In-plane perpendiculars from edge into each face
            var T1 = normalize(cross(fm.n1, edgeDir))
            if dot(T1, mesh.vertices[fm.c1].position - midEdge) < 0 { T1 = -T1 }

            var T2 = normalize(cross(fm.n2, edgeDir))
            if dot(T2, mesh.vertices[fm.c2].position - midEdge) < 0 { T2 = -T2 }

            let cosAngle = dot(T1, T2)
            guard abs(cosAngle) < 0.9999 else { continue }

            let T2ortho = normalize(T2 - cosAngle * T1)
            let inAngle = acos(clamp(cosAngle, -1, 1))

            // Catmull-Rom control points for fillet profile
            // P0: extrapolated along face 1 (defines tangent at P1)
            // P1: tangent point on face 1 at radius
            // P2: tangent point on face 2 at radius
            // P3: extrapolated along face 2 (defines tangent at P2)
            let cp0 = radius * T1 * 1.5
            let cp1 = radius * T1
            let cp2 = radius * T2
            let cp3 = radius * T2 * 1.5

            // For large angles, use sin/cos arc; for small angles, use Catmull-Rom
            let useArcTransition = inAngle > 0.3

            var grid = [[Int]]()

            for i in 0...segments {
                let t = Float(i) / Float(segments)
                let edgePos = simd_mix(posA, posB, t)
                var row = [Int]()

                for j in 0...segments {
                    let s = Float(j) / Float(segments)

                    let offset: SIMD3<Float>
                    let normal: SIMD3<Float>

                    if useArcTransition {
                        let angle = s * inAngle * 0.5
                        let blendAngle = s * (Float.pi * 0.5)
                        offset = radius * (
                            (1 - sin(blendAngle)) * T1 +
                            (1 - cos(blendAngle)) * T2ortho
                        )
                        normal = normalize(-(sin(blendAngle) * T1 + cos(blendAngle) * T2ortho))
                    } else {
                        // Catmull-Rom spline for smooth fillet profile
                        let cr = catmullRom3D(p0: cp0, p1: cp1, p2: cp2, p3: cp3, t: s)
                        offset = cr
                        // Normal: perpendicular to spline tangent
                        let dt = Float(0.01)
                        let crA = catmullRom3D(p0: cp0, p1: cp1, p2: cp2, p3: cp3, t: max(s - dt, 0))
                        let crB = catmullRom3D(p0: cp0, p1: cp1, p2: cp2, p3: cp3, t: min(s + dt, 1))
                        let tangent = normalize(crB - crA)
                        let edgeNormal = cross(edgeDir, tangent)
                        normal = normalize(cross(tangent, edgeNormal))
                    }

                    let pos = edgePos + offset
                    let v = Vertex(position: pos, normal: normal, uv: .zero)
                    row.append(newVertices.count)
                    newVertices.append(v)
                }
                grid.append(row)
            }
            edgeGridMap[key] = grid
        }

        // 3. Stitch fillet surface triangles
        for (key, grid) in edgeGridMap {
            // Fillet surface strip
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

            // Gap-fill fans connecting fillet to adjacent faces
            guard let fm = edgeFaceMap[key] else { continue }

            // Recover edge endpoints from the key
            let edgeA = key / (originalCount > 0 ? originalCount : 1) % originalCount
            let edgeB = key % originalCount
            // Correct extraction: key = min*N + max
            let nCount = originalCount > 0 ? originalCount : 1
            let edgeMin = key / nCount
            var edgeMax = key % nCount
            if edgeMax <= edgeMin { edgeMax = key - edgeMin * nCount }

            let a = edges.first(where: { min($0.0, $0.1) == edgeMin && max($0.0, $0.1) == edgeMax })?.0 ?? edgeMin
            let b = edges.first(where: { min($0.0, $0.1) == edgeMin && max($0.0, $0.1) == edgeMax })?.1 ?? edgeMax

            let c1 = fm.c1
            let c2 = fm.c2

            // Face 1 fan: from opposite vertex c1 to fillet boundary (col 0)
            newIndices.append(contentsOf: [UInt32(c1), UInt32(a), UInt32(grid[0][0])])
            for i in 0..<segments {
                newIndices.append(contentsOf: [UInt32(c1), UInt32(grid[i][0]), UInt32(grid[i+1][0])])
            }
            newIndices.append(contentsOf: [UInt32(c1), UInt32(grid[segments][0]), UInt32(b)])

            // Face 2 fan: from opposite vertex c2 to fillet boundary (col segments)
            newIndices.append(contentsOf: [UInt32(c2), UInt32(grid[0][segments]), UInt32(a)])
            for i in 0..<segments {
                newIndices.append(contentsOf: [UInt32(c2), UInt32(grid[i+1][segments]), UInt32(grid[i][segments])])
            }
            newIndices.append(contentsOf: [UInt32(c2), UInt32(b), UInt32(grid[segments][segments])])

            // End caps connecting original edge vertices to fillet endpoints
            for j in 0..<segments {
                newIndices.append(contentsOf: [UInt32(a), UInt32(grid[0][j]), UInt32(grid[0][j+1])])
                newIndices.append(contentsOf: [UInt32(b), UInt32(grid[segments][j+1]), UInt32(grid[segments][j])])
            }
        }

        // 4. Copy unaffected triangles
        for i in stride(from: 0, to: mesh.indices.count, by: 3) {
            guard !removedTriangles.contains(i) else { continue }
            newIndices.append(contentsOf: [mesh.indices[i], mesh.indices[i+1], mesh.indices[i+2]])
        }

        mesh = Mesh(vertices: newVertices, indices: newIndices)
        return true
    }

    // MARK: - Catmull-Rom spline (3D)
    private func catmullRom3D(
        p0: SIMD3<Float>,
        p1: SIMD3<Float>,
        p2: SIMD3<Float>,
        p3: SIMD3<Float>,
        t: Float
    ) -> SIMD3<Float> {
        let t2 = t * t
        let t3 = t2 * t
        let m0 = 0.5 * (p2 - p0)
        let m1 = 0.5 * (p3 - p1)
        // Hermite form: (2t³ - 3t² + 1)*P1 + (t³ - 2t² + t)*M0 + (-2t³ + 3t²)*P2 + (t³ - t²)*M1
        let h00 =  2 * t3 - 3 * t2 + 1
        let h10 =       t3 - 2 * t2 + t
        let h01 = -2 * t3 + 3 * t2
        let h11 =       t3 -     t2
        return h00 * p1 + h10 * m0 + h01 * p2 + h11 * m1
    }

    private func clamp(_ x: Float, _ lo: Float, _ hi: Float) -> Float {
        return max(lo, min(hi, x))
    }
}
