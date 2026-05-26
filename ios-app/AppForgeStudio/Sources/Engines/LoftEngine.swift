import Foundation
import simd
import OSLog

private let logger = Logger(subsystem: "com.appforgestudio", category: "LoftEngine")

class LoftEngine {

    func computeLoft(curves: [[Vertex]], segments: Int = 8) -> Mesh {
        guard curves.count >= 2, segments > 0, curves[0].count >= 3 else { return Mesh() }

        let ptsPerCurve = curves[0].count
        for (i, crv) in curves.enumerated() {
            guard crv.count == ptsPerCurve else {
                logger.warning("LoftEngine: curve \(i) has \(crv.count) points, expected \(ptsPerCurve)")
                return Mesh()
            }
        }

        var vertices = [Vertex]()
        var indices = [UInt32]()
        var grid = [[Int]]()

        for c in 0..<(curves.count - 1) {
            let from = curves[c]
            let to = curves[c + 1]

            for s in 0...(segments + 1) {
                let t = min(Float(s) / Float(segments), 1.0)
                var row = [Int]()

                for p in 0..<ptsPerCurve {
                    let pos = simd_mix(from[p].position, to[p].position, t)
                    let nrm = normalize(simd_mix(from[p].normal, to[p].normal, t))
                    let uv = simd_mix(from[p].uv, to[p].uv, t)
                    row.append(vertices.count)
                    vertices.append(Vertex(position: pos, normal: nrm, uv: uv))
                }
                grid.append(row)

                if s == segments + 1 && c < curves.count - 2 {
                    grid.removeLast()
                }
            }
        }

        for i in 0..<(grid.count - 1) {
            for p in 0..<ptsPerCurve {
                let a0 = grid[i][p]
                let a1 = grid[i][(p + 1) % ptsPerCurve]
                let b0 = grid[i + 1][p]
                let b1 = grid[i + 1][(p + 1) % ptsPerCurve]

                indices.append(contentsOf: [UInt32(a0), UInt32(a1), UInt32(b1)])
                indices.append(contentsOf: [UInt32(a0), UInt32(b1), UInt32(b0)])
            }
        }

        return Mesh(vertices: vertices, indices: indices)
    }
}
