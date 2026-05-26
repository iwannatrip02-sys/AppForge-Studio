import Foundation
import simd
import OSLog

private let logger = Logger(subsystem: "com.appforgestudio", category: "LoftEngine")

class LoftEngine {

    func computeLoft(curves: [[Vertex]], segments: Int = 8) -> Mesh {
        guard curves.count >= 2 else {
            logger.warning("Loft requires at least 2 curves")
            return Mesh()
        }

        // Ensure all curves have the same vertex count by resampling
        let maxVertices = curves.map { $0.count }.max() ?? 0
        guard maxVertices >= 3 else {
            logger.warning("Loft curves need at least 3 vertices each")
            return Mesh()
        }

        var resampledCurves: [[Vertex]] = []
        let templateVertexCount = maxVertices
        for curve in curves {
            if curve.count == templateVertexCount {
                resampledCurves.append(curve)
            } else {
                resampledCurves.append(resampleCurve(curve, targetCount: templateVertexCount))
            }
        }

        var vertices = [Vertex]()
        var indices = [UInt32]()
        let profileCount = resampledCurves[0].count
        let samplesPerPair = segments + 1

        // For each pair of consecutive curves, generate interpolated surface
        for ci in 0..<(resampledCurves.count - 1) {
            let curveA = resampledCurves[ci]
            let curveB = resampledCurves[ci + 1]

            // Generate interpolated rings
            var ringIndices: [[Int]] = []

            for s in 0...segments {
                let t = Float(s) / Float(segments)
                var ringVerts = [Int]()

                for vi in 0..<profileCount {
                    let vA = curveA[vi]
                    let vB = curveB[vi]

                    // Catmull-Rom interpolation between curves
                    // For the first/last curve, use linear interpolation; for intermediate, use spline
                    let pos: SIMD3<Float>
                    let normal: SIMD3<Float>
                    let uv: SIMD2<Float>

                    if resampledCurves.count == 2 || ci == 0 && resampledCurves.count > 2 {
                        // Linear interpolation for simple case
                        pos = simd_mix(vA.position, vB.position, t)
                        normal = normalize(simd_mix(vA.normal, vB.normal, t))
                        uv = SIMD2<Float>(Float(vi) / Float(profileCount - 1), t)
                    } else {
                        // Catmull-Rom spline through all curves
                        let c0 = max(ci - 1, 0)
                        let c1 = ci
                        let c2 = ci + 1
                        let c3 = min(ci + 2, resampledCurves.count - 1)
                        let p0 = resampledCurves[c0][vi].position
                        let p1 = vA.position
                        let p2 = vB.position
                        let p3 = resampledCurves[c3][vi].position
                        pos = catmullRom3D(p0: p0, p1: p1, p2: p2, p3: p3, t: t)
                        normal = normalize(simd_mix(vA.normal, vB.normal, t))
                        uv = SIMD2<Float>(Float(vi) / Float(profileCount - 1), Float(ci) / Float(resampledCurves.count - 1))
                    }

                    ringVerts.append(vertices.count)
                    vertices.append(Vertex(position: pos, normal: normal, uv: uv))
                }
                ringIndices.append(ringVerts)
            }

            // Stitch triangle strips between rings
            for s in 0..<segments {
                let ringA = ringIndices[s]
                let ringB = ringIndices[s + 1]

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

                // Close the ring (last vertex to first vertex)
                let a0 = ringA[profileCount - 1]
                let a1 = ringA[0]
                let b0 = ringB[profileCount - 1]
                let b1 = ringB[0]

                indices.append(contentsOf: [
                    UInt32(a0), UInt32(b0), UInt32(b1),
                    UInt32(a0), UInt32(b1), UInt32(a1)
                ])
            }
        }

        // Cap start and end
        if let firstRing = resampledCurves.first {
            // Start cap: fan from first vertex to all other ring vertices
            let startBase = vertices.count
            var startRingVerts = [Int]()
            for vi in 0..<profileCount {
                let v = firstRing[vi]
                startRingVerts.append(vertices.count)
                vertices.append(Vertex(
                    position: v.position,
                    normal: -normalize(cross(
                        firstRing[(vi + 1) % profileCount].position - v.position,
                        firstRing[(vi + profileCount - 1) % profileCount].position - v.position
                    )),
                    uv: v.uv
                ))
            }
            for vi in 1..<(profileCount - 1) {
                indices.append(contentsOf: [
                    UInt32(startRingVerts[0]),
                    UInt32(startRingVerts[vi]),
                    UInt32(startRingVerts[vi + 1])
                ])
            }
        }

        if let lastRing = resampledCurves.last {
            let endBase = vertices.count
            var endRingVerts = [Int]()
            for vi in 0..<profileCount {
                let v = lastRing[vi]
                endRingVerts.append(vertices.count)
                vertices.append(Vertex(
                    position: v.position,
                    normal: normalize(cross(
                        lastRing[(vi + 1) % profileCount].position - v.position,
                        lastRing[(vi + profileCount - 1) % profileCount].position - v.position
                    )),
                    uv: v.uv
                ))
            }
            for vi in 1..<(profileCount - 1) {
                indices.append(contentsOf: [
                    UInt32(endRingVerts[0]),
                    UInt32(endRingVerts[vi + 1]),
                    UInt32(endRingVerts[vi])
                ])
            }
        }

        return Mesh(vertices: vertices, indices: indices)
    }

    // MARK: - Helpers

    private func resampleCurve(_ curve: [Vertex], targetCount: Int) -> [Vertex] {
        guard targetCount > 1, !curve.isEmpty else { return curve }
        var result = [Vertex]()
        for i in 0..<targetCount {
            let t = Float(i) / Float(targetCount - 1)
            let idx = Float(curve.count - 1) * t
            let lo = Int(floor(idx))
            let hi = min(lo + 1, curve.count - 1)
            let frac = idx - Float(lo)
            let pos = simd_mix(curve[lo].position, curve[hi].position, frac)
            let normal = normalize(simd_mix(curve[lo].normal, curve[hi].normal, frac))
            let uv = simd_mix(curve[lo].uv, curve[hi].uv, frac)
            result.append(Vertex(position: pos, normal: normal, uv: uv))
        }
        return result
    }

    private func catmullRom3D(
        p0: SIMD3<Float>, p1: SIMD3<Float>,
        p2: SIMD3<Float>, p3: SIMD3<Float>,
        t: Float
    ) -> SIMD3<Float> {
        let t2 = t * t
        let t3 = t2 * t
        let m0 = 0.5 * (p2 - p0)
        let m1 = 0.5 * (p3 - p1)
        let h00 =  2 * t3 - 3 * t2 + 1
        let h10 =       t3 - 2 * t2 + t
        let h01 = -2 * t3 + 3 * t2
        let h11 =       t3 -     t2
        return h00 * p1 + h10 * m0 + h01 * p2 + h11 * m1
    }
}
