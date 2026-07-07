import Foundation
import CoreGraphics
import simd
import OCCTSwift

// MARK: - Rayo de cámara

/// Rayo perspectiva en coordenadas de mundo.
/// Generación ÚNICA y testeable (antes duplicada dentro de MetalView).
struct CameraRay {
    let origin: SIMD3<Float>
    let direction: SIMD3<Float>

    /// Rayo desde un punto de pantalla (px) usando la cámara de la escena.
    /// Misma matemática que usaba MetalView — extraída sin cambio de comportamiento.
    static func from(screenPoint: CGPoint, viewSize: CGSize, camera: Scene3D.Camera) -> CameraRay {
        let aspect = Float(viewSize.width / max(viewSize.height, 1))
        let ndc = SIMD2<Float>(
            (2 * Float(screenPoint.x) / Float(viewSize.width) - 1) * aspect,
            1 - 2 * Float(screenPoint.y) / Float(viewSize.height)
        )
        let fovRad = camera.fov * .pi / 180
        let halfH = tan(fovRad * 0.5)
        let halfW = halfH * aspect

        let forward = simd_normalize(camera.target - camera.position)
        let right = simd_normalize(simd_cross(forward, camera.up))
        let up = simd_cross(right, forward)
        let direction = simd_normalize(forward + right * ndc.x * halfW + up * ndc.y * halfH)
        return CameraRay(origin: camera.position, direction: direction)
    }
}

// MARK: - Hit de superficie

/// Impacto de un rayo contra la escena: el dato que la UI necesita para
/// selección directa (tap-en-geometría), sculpt y push/pull.
struct SurfaceHit {
    let modelIndex: Int
    let position: SIMD3<Float>
    let normal: SIMD3<Float>
    let distance: Float
}

// MARK: - Picker de escena (malla)

enum ScenePicker {

    /// Hit más cercano del rayo contra las mallas de todos los modelos.
    static func hitTest(models: [Model], ray: CameraRay) -> SurfaceHit? {
        var best: SurfaceHit?
        for (modelIndex, model) in models.enumerated() {
            for mesh in model.meshes {
                var j = 0
                while j + 2 < mesh.indices.count {
                    let i0 = Int(mesh.indices[j])
                    let i1 = Int(mesh.indices[j + 1])
                    let i2 = Int(mesh.indices[j + 2])
                    j += 3
                    guard i0 < mesh.vertices.count, i1 < mesh.vertices.count,
                          i2 < mesh.vertices.count else { continue }
                    let v0 = mesh.vertices[i0].position
                    let v1 = mesh.vertices[i1].position
                    let v2 = mesh.vertices[i2].position
                    guard let hit = rayTriangleIntersect(rayOrigin: ray.origin, rayDir: ray.direction,
                                                         v0: v0, v1: v1, v2: v2) else { continue }
                    let dist = simd_distance(ray.origin, hit)
                    guard dist < (best?.distance ?? .greatestFiniteMagnitude) else { continue }

                    let faceNormal = simd_normalize(simd_cross(v1 - v0, v2 - v0))
                    let interpolated = mesh.vertices[i0].normal + mesh.vertices[i1].normal + mesh.vertices[i2].normal
                    let normal = simd_length(interpolated) > 0.001
                        ? simd_normalize(interpolated)
                        : faceNormal
                    best = SurfaceHit(modelIndex: modelIndex, position: hit,
                                      normal: normal, distance: dist)
                }
            }
        }
        return best
    }
}

// MARK: - Picker de caras B-rep

/// Del punto de impacto sobre la malla de display a la cara B-rep correspondiente.
/// Puente crítico para la manipulación directa estilo Shapr3D: el dedo toca
/// triángulos, la ingeniería opera sobre caras.
enum BRepFacePicker {

    /// Índice de la cara del shape más cercana al punto (proyección de superficie OCCT).
    /// `maxDistance` en unidades de mundo — descarta toques lejos de toda cara.
    static func faceIndex(of shape: CADShape, nearest point: SIMD3<Float>,
                          maxDistance: Double = 0.05) -> Int? {
        let p = SIMD3<Double>(Double(point.x), Double(point.y), Double(point.z))
        var bestIndex: Int?
        var bestDistance = Double.greatestFiniteMagnitude
        for (i, face) in shape.faces().enumerated() {
            guard let projection = face.project(point: p) else { continue }
            if projection.distance < bestDistance {
                bestDistance = projection.distance
                bestIndex = i
            }
        }
        return bestDistance <= maxDistance ? bestIndex : nil
    }
}
