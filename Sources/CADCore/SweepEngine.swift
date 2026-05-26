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
        guard profile.count >= 3, path.count >= 2 else {
            logger.warning("Sweep requires profile (3+ vertices) and path (2+ points)")
            return Mesh()
        }

        // Resample path at uniform segments
        let resampledPath = resamplePath(path, targetCount: segments + 1)

        var vertices = [Vertex]()
        var indices = [UInt32]()
        let profileCount = profile.count
        let pathCount = resampledPath.count

        // Build local frames at each path point
        var frames = [Frame]()
        for i in 0..<pathCount {
            let tangent = resampledPath[i].tangent
            let normal: SIMD3<Float>
            let binormal: SIMD3<Float>

            if i == 0 {
                // Initial frame: use a reference up vector
                let up = SIMD3<Float>(0, 1, 0)
                if abs(dot(up, tangent)) > 0.999 {
                    normal = normalize(cross(SIMD3<Float>(1, 0, 0), tangent))
                } else {
                    normal = normalize(cross(up, tangent))
                }
                binormal = cross(tangent, normal)
            } else {
                // Propagate frame from previous using parallel transport
                let prevFrame = frames[i - 1]
                let prevT = resampledPath[i - 1].tangent

                // Rotation to align previous tangent with current tangent
                let rotAxis = normalize(cross(prevT, tangent))
                let rotAngle = acos(clamp(dot(prevT, tangent), -1, 1))

                if abs(rotAngle) < 1e-6 {
                    normal = prevFrame.normal
                    binormal = prevFrame.binormal
                } else {
                    normal = rotateVector(prevFrame.normal, axis: rotAxis, angle: rotAngle)
                    binormal = cross(tangent, normal)
                }
            }

            frames.append(Frame(tangent: tangent, normal: normal, binormal: binormal))
        }

        // Generate profile rings along the path
        var ringIndices: [[Int]] = []

        for pi in 0..<pathCount {
            let frame = frames[pi]
            let pathPos = resampledPath[pi].position
            var ringVerts = [Int]()

            for vi in 0..<profileCount {
                let pv = profile[vi].position
                // Transform profile from local 2D coordinates to 3D world
                let worldPos = pathPos + pv.x * frame.normal + pv.y * frame.binormal
                let worldNormal = normalize(
                    profile[vi].normal.x * frame.normal +
                    profile[vi].normal.y * frame.binormal +
                    profile[vi].normal.z * frame.tangent
                )
                let progress = Float(pi) / Float(pathCount - 1)
                let uv = SIMD2<Float>(Float(vi) / Float(profileCount - 1), progress)

                ringVerts.append(vertices.count)
                vertices.append(Vertex(position: worldPos, normal: worldNormal, uv: uv))
            }
            ringIndices.append(ringVerts)
        }

        // Stitch triangle strips between consecutive rings
        for pi in 0..<(pathCount - 1) {
            let ringA = ringIndices[pi]
            let ringB = ringIndices[pi + 1]

            for vi in 0..<(profileCount - 1) {
                let a0 = ringA[vi]
                let a1 = ringA[vi + 1]
                let b0 = ringB[vi]
                let b1 = ringB[vi + 1]

                indices.append(contentsOf: [
                    UInt32(a0), UInt32(b0), UInt32(b1),
                    UInt32(a0), UInt32(b1), UInt32(a1)
                ])
            }

            // Close the ring
            let a0 = ringA[profileCount - 1]
            let a1 = ringA[0]
            let b0 = ringB[profileCount - 1]
            let b1 = ringB[0]

            indices.append(contentsOf: [
                UInt32(a0), UInt32(b0), UInt32(b1),
                UInt32(a0), UInt32(b1), UInt32(a1)
            ])
        }

        // Cap start
        do {
            let firstFrame = frames[0]
            let firstPos = resampledPath[0].position
            let capCenter = vertices.count
            vertices.append(Vertex(
                position: firstPos,
                normal: -firstFrame.tangent,
                uv: SIMD2<Float>(0.5, 0)
            ))

            let ringA = ringIndices[0]
            for vi in 0..<(profileCount - 1) {
                indices.append(contentsOf: [
                    UInt32(capCenter),
                    UInt32(ringA[vi + 1]),
                    UInt32(ringA[vi])
                ])
            }
            indices.append(contentsOf: [
                UInt32(capCenter),
                UInt32(ringA[0]),
                UInt32(ringA[profileCount - 1])
            ])
        }

        // Cap end
        do {
            let lastFrame = frames[pathCount - 1]
            let lastPos = resampledPath[pathCount - 1].position
            let capCenter = vertices.count
            vertices.append(Vertex(
                position: lastPos,
                normal: lastFrame.tangent,
                uv: SIMD2<Float>(0.5, 1)
            ))

            let ringB = ringIndices[pathCount - 1]
            for vi in 0..<(profileCount - 1) {
                indices.append(contentsOf: [
                    UInt32(capCenter),
                    UInt32(ringB[vi]),
                    UInt32(ringB[vi + 1])
                ])
            }
            indices.append(contentsOf: [
                UInt32(capCenter),
                UInt32(ringB[profileCount - 1]),
                UInt32(ringB[0])
            ])
        }

        return Mesh(vertices: vertices, indices: indices)
    }

    // MARK: - Helpers

    private struct Frame {
        let tangent: SIMD3<Float>
        let normal: SIMD3<Float>
        let binormal: SIMD3<Float>
    }

    private func resamplePath(_ path: [(position: SIMD3<Float>, tangent: SIMD3<Float>)], targetCount: Int) -> [(position: SIMD3<Float>, tangent: SIMD3<Float>)] {
        guard targetCount > 1, path.count >= 2 else { return path }

        // Compute cumulative path length
        var lengths = [Float](repeating: 0, count: path.count)
        for i in 1..<path.count {
            lengths[i] = lengths[i - 1] + distance(path[i - 1].position, path[i].position)
        }
        let totalLen = lengths[path.count - 1]
        guard totalLen > 1e-6 else { return path }

        var result: [(SIMD3<Float>, SIMD3<Float>)] = []
        for i in 0..<targetCount {
            let targetDist = Float(i) / Float(targetCount - 1) * totalLen
            // Find segment containing targetDist
            var segIdx = 0
            for j in 1..<path.count {
                if targetDist <= lengths[j] {
                    segIdx = j - 1
                    break
                }
                if j == path.count - 1 {
                    segIdx = path.count - 2
                }
            }

            let segStart = lengths[segIdx]
            let segEnd = lengths[segIdx + 1]
            let segLen = segEnd - segStart
            let t = segLen > 1e-6 ? (targetDist - segStart) / segLen : 0
            let clampedT = max(0, min(1, t))

            let pos = simd_mix(path[segIdx].position, path[segIdx + 1].position, clampedT)
            let tangent = normalize(simd_mix(path[segIdx].tangent, path[segIdx + 1].tangent, clampedT))

            result.append((position: pos, tangent: tangent))
        }

        return result
    }

    private func rotateVector(_ v: SIMD3<Float>, axis: SIMD3<Float>, angle: Float) -> SIMD3<Float> {
        let cosA = cos(angle)
        let sinA = sin(angle)
        let dotVA = dot(v, axis)
        return cosA * v + sinA * cross(axis, v) + (1 - cosA) * dotVA * axis
    }

    private func clamp(_ x: Float, _ lo: Float, _ hi: Float) -> Float {
        return max(lo, min(hi, x))
    }
}
