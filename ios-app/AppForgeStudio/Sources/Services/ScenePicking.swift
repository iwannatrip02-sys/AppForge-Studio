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
    /// Los modelos con nombre `__*` son overlays de UI (highlight de cara, gizmos)
    /// y NO son geometría tocable.
    static func hitTest(models: [Model], ray: CameraRay) -> SurfaceHit? {
        var best: SurfaceHit?
        for (modelIndex, model) in models.enumerated() {
            guard !model.name.hasPrefix("__") else { continue }
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

    /// Malla de highlight para una cara B-rep: los triángulos de la malla de display
    /// cuyos vértices yacen sobre la cara, desplazados por su normal para evitar
    /// z-fighting. Es el feedback visual de selección (prioridad 1 del doc de diseño).
    static func highlightMesh(shape: CADShape, faceIndex: Int, displayMesh: Mesh,
                              tolerance: Double = 1e-3, offset: Float = 0.002) -> Mesh? {
        let faces = shape.faces()
        guard faceIndex >= 0, faceIndex < faces.count else { return nil }
        let face = faces[faceIndex]

        func liesOnFace(_ p: SIMD3<Float>) -> Bool {
            let projected = face.project(point: SIMD3<Double>(Double(p.x), Double(p.y), Double(p.z)))
            guard let projection = projected else { return false }
            return projection.distance < tolerance
        }

        var vertices: [Vertex] = []
        var indices: [UInt32] = []
        var j = 0
        while j + 2 < displayMesh.indices.count {
            let tri = [Int(displayMesh.indices[j]), Int(displayMesh.indices[j + 1]),
                       Int(displayMesh.indices[j + 2])]
            j += 3
            guard tri.allSatisfy({ $0 < displayMesh.vertices.count }),
                  tri.allSatisfy({ liesOnFace(displayMesh.vertices[$0].position) }) else { continue }
            let base = UInt32(vertices.count)
            for vi in tri {
                var v = displayMesh.vertices[vi]
                v.position += v.normal * offset
                vertices.append(v)
            }
            indices.append(contentsOf: [base, base + 1, base + 2])
        }
        return vertices.isEmpty ? nil : Mesh(vertices: vertices, indices: indices)
    }

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
