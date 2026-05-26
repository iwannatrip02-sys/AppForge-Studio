import Foundation
import simd
import OSLog

private let logger = Logger(subsystem: "com.appforgestudio", category: "SweepEngine")

class SweepEngine {

    func computeSweep(
        profile: [Vertex],
        path: [(position: SIMD3<Float>, tangent: SIMD3<Float>)],
        segments: Int = 12
    ) -> Mesh {
        guard profile.count >= 3, path.count >= 2, segments > 0 else { return Mesh() }

        // Resample path into (segments+1) uniform points with Frenet frames
        var frames = [(pos: SIMD3<Float>, T: SIMD3<Float>, N: SIMD3<Float>, B: SIMD3<Float>)]()
        for s in 0...segments {
            let t = Float(s) / Float(segments)
            let sampled = resamplePath(path, t)
            let T = normalize(sampled.tangent)
            guard length(T) > 1e-6 else {
                logger.warning("SweepEngine: zero tangent at t=\(t)")
                return Mesh()
            }
            let ref = abs(T.y) < 0.999 ? SIMD3<Float>(0, 1, 0) : SIMD3<Float>(1, 0, 0)
            let N = normalize(cross(T, ref))
            let B = normalize(cross(T, N))
            frames.append((sampled.position, T, N, B))
        }

        let nProfile = profile.count
        var vertices = [Vertex]()
        var grid = [[Int]]()

        // Place profile at each frame
        for s in 0...(segments) {
            let f = frames[s]
            var row = [Int]()

            for p in 0..<nProfile {
                let prof = profile[p]
                let worldPos = f.pos + prof.position.x * f.N + prof.position.y * f.B
                let worldNrm = normalize(prof.normal.x * f.N + prof.normal.y * f.B)
                row.append(vertices.count)
                vertices.append(Vertex(position: worldPos, normal: worldNrm, uv: prof.uv))
            }
            grid.append(row)
        }

        var indices = [UInt32]()

        // Stitch rings
        for s in 0..<segments {
            for p in 0..<nProfile {
                let a0 = grid[s][p]
                let a1 = grid[s][(p + 1) % nProfile]
                let b0 = grid[s + 1][p]
                let b1 = grid[s + 1][(p + 1) % nProfile]

                indices.append(contentsOf: [UInt32(a0), UInt32(a1), UInt32(b1)])
                indices.append(contentsOf: [UInt32(a0), UInt32(b1), UInt32(b0)])
            }
        }

        return Mesh(vertices: vertices, indices: indices)
    }

    private func resamplePath(
        _ path: [(position: SIMD3<Float>, tangent: SIMD3<Float>)],
        _ t: Float
    ) -> (position: SIMD3<Float>, tangent: SIMD3<Float>) {
        let n = path.count
        let scaled = t * Float(n - 1)
        let idx = min(Int(scaled), n - 2)
        let localT = scaled - Float(idx)

        let p0 = path[idx]
        let p1 = path[min(idx + 1, n - 1)]
        return (
            simd_mix(p0.position, p1.position, localT),
            normalize(simd_mix(p0.tangent, p1.tangent, localT))
        )
    }
}
