import Foundation
import simd
import CoreGraphics

struct HitResult {
    let position: SIMD3<Float>
    let entityID: UUID
    let distance: Float
}

class HitTestEngine {

    func hitTest(
        at screenPoint: CGPoint,
        in size: CGSize,
        scene: Scene3D
    ) -> HitResult? {
        let rayOrigin = SIMD3<Float>(0, 0, 3)
        let ndcX = Float(screenPoint.x / size.width) * 2 - 1
        let ndcY = Float(1 - screenPoint.y / size.height) * 2 - 1
        let rayDir = simd_normalize(SIMD3<Float>(ndcX, ndcY, -1))

        var closest: HitResult? = nil
        var closestDist: Float = .infinity

        for model in scene.models {
            let invTransform = simd_inverse(model.transform)

            let localOrigin3 = invTransform * SIMD4<Float>(rayOrigin.x, rayOrigin.y, rayOrigin.z, 1)
            let localOrigin = SIMD3<Float>(localOrigin3.x, localOrigin3.y, localOrigin3.z)

            let localDir3 = invTransform * SIMD4<Float>(rayDir.x, rayDir.y, rayDir.z, 0)
            let localDir = simd_normalize(SIMD3<Float>(localDir3.x, localDir3.y, localDir3.z))

            for mesh in model.meshes {
                for i in stride(from: 0, to: mesh.indices.count, by: 3) {
                    let i0 = Int(mesh.indices[i])
                    let i1 = Int(mesh.indices[i + 1])
                    let i2 = Int(mesh.indices[i + 2])
                    guard i0 < mesh.vertices.count,
                          i1 < mesh.vertices.count,
                          i2 < mesh.vertices.count else { continue }

                    let v0 = mesh.vertices[i0].position
                    let v1 = mesh.vertices[i1].position
                    let v2 = mesh.vertices[i2].position

                    if let (t, u, v) = rayTriangleIntersection(
                        origin: localOrigin,
                        direction: localDir,
                        v0: v0, v1: v1, v2: v2
                    ), t > 0, t < closestDist {
                        let hitLocal = localOrigin + localDir * t
                        let hitWorld4 = model.transform * SIMD4<Float>(hitLocal.x, hitLocal.y, hitLocal.z, 1)
                        let hitWorld = SIMD3<Float>(hitWorld4.x, hitWorld4.y, hitWorld4.z)
                        closestDist = t
                        closest = HitResult(
                            position: hitWorld,
                            entityID: model.id,
                            distance: t
                        )
                    }
                }
            }
        }

        return closest
    }

    private func rayTriangleIntersection(
        origin: SIMD3<Float>,
        direction: SIMD3<Float>,
        v0: SIMD3<Float>,
        v1: SIMD3<Float>,
        v2: SIMD3<Float>
    ) -> (t: Float, u: Float, v: Float)? {
        let e1 = v1 - v0
        let e2 = v2 - v0
        let h = simd_cross(direction, e2)
        let a = simd_dot(e1, h)

        if abs(a) < 1e-7 { return nil }

        let f: Float = 1.0 / a
        let s = origin - v0
        let u = f * simd_dot(s, h)

        if u < 0 || u > 1 { return nil }

        let q = simd_cross(s, e1)
        let v = f * simd_dot(direction, q)

        if v < 0 || u + v > 1 { return nil }

        let t = f * simd_dot(e2, q)
        if t < 0 { return nil }

        return (t, u, v)
    }
}
