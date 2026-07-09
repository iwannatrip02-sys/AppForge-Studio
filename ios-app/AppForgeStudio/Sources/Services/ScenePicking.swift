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
            guard !model.name.hasPrefix("__"), model.isVisible else { continue }
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

// MARK: - Picker de aristas B-rep

/// Del punto de impacto a la ARISTA B-rep más cercana. Fundamento del menú
/// adaptativo (BLUEPRINT S2): tocar cerca de una arista ofrece fillet/chamfer;
/// lejos de toda arista, la selección es de cara. API Edge verificada @v1.8.8:
/// `Shape.edges() -> [Edge]`, `Edge.project(point:) -> CurveProjection?`.
enum BRepEdgePicker {

    /// Índice de la arista más cercana al punto (proyección de curva OCCT).
    /// `maxDistance` más apretado que el de cara: una arista es un objetivo fino
    /// y solo debe ganar cuando el toque es claramente sobre ella.
    static func edgeIndex(of shape: CADShape, nearest point: SIMD3<Float>,
                          maxDistance: Double = 0.03) -> Int? {
        let p = SIMD3<Double>(Double(point.x), Double(point.y), Double(point.z))
        var bestIndex: Int?
        var bestDistance = Double.greatestFiniteMagnitude
        for (i, edge) in shape.edges().enumerated() {
            guard let projection = edge.project(point: p) else { continue }
            if projection.distance < bestDistance {
                bestDistance = projection.distance
                bestIndex = i
            }
        }
        return bestDistance <= maxDistance ? bestIndex : nil
    }

    /// Polilínea muestreada de la arista (para el overlay de highlight en el render).
    static func polyline(of shape: CADShape, edgeIndex: Int,
                         samples: Int = 32) -> [SIMD3<Float>]? {
        let edges = shape.edges()
        guard edgeIndex >= 0, edgeIndex < edges.count else { return nil }
        let pts = edges[edgeIndex].points(count: samples)
        guard !pts.isEmpty else { return nil }
        return pts.map { SIMD3<Float>(Float($0.x), Float($0.y), Float($0.z)) }
    }

    /// Malla de highlight para una arista: tubo cuadrado delgado a lo largo de la
    /// curva (el render dibuja mallas, no líneas). Feedback visual de selección.
    static func highlightTube(shape: CADShape, edgeIndex: Int,
                              radius: Float = 0.012) -> Mesh? {
        guard let pts = polyline(of: shape, edgeIndex: edgeIndex), pts.count >= 2 else {
            return nil
        }
        var vertices: [Vertex] = []
        var indices: [UInt32] = []

        for i in 0..<(pts.count - 1) {
            let p0 = pts[i], p1 = pts[i + 1]
            let dir = simd_normalize(p1 - p0)
            // Perpendiculares estables: elegir el eje mundial menos alineado con dir
            let ref: SIMD3<Float> = abs(dir.x) < 0.9 ? SIMD3<Float>(1, 0, 0) : SIMD3<Float>(0, 1, 0)
            let u = simd_normalize(simd_cross(dir, ref)) * radius
            let v = simd_normalize(simd_cross(dir, u)) * radius

            let base = UInt32(vertices.count)
            for p in [p0, p1] {
                for offset in [u, v, -u, -v] {
                    vertices.append(Vertex(position: p + offset,
                                           normal: simd_normalize(offset), uv: .zero))
                }
            }
            // 4 caras laterales del prisma (anillo p0: base+0..3, anillo p1: base+4..7)
            for k in 0..<4 {
                let a = base + UInt32(k)
                let b = base + UInt32((k + 1) % 4)
                let c = a + 4
                let d = b + 4
                indices.append(contentsOf: [a, b, c, b, d, c])
            }
        }
        return Mesh(vertices: vertices, indices: indices)
    }
}
