import Foundation
import CoreGraphics
import simd
import OCCTSwift

// MARK: - Constructor de CINTAS de línea (líneas nítidas AA, look Shapr3D)

/// Genera geometría de LÍNEA plana (no tubos 3D). Cada segmento es una cinta de 2
/// triángulos; el shader `edge_line_vertex` la expande en espacio de pantalla a un
/// grosor CONSTANTE en píxeles y `edge_line_fragment` la dibuja con núcleo oscuro +
/// halo claro anti-aliased. Sustituye a `appendTube`/octaedro (los "tubos 3D" feos).
///
/// Encoding en el `Vertex` estándar (sin tocar el vertex descriptor del pipeline):
///   position = P (punto de la espina) · normal = Q (otro punto del segmento) ·
///   uv.x = lado con signo [-1,+1] · uv.y = 0 línea / 1 punto.
enum LineRibbonBuilder {

    /// Añade una polilínea como cintas de línea. `closed` cierra el lazo P_last→P_0.
    static func appendPolyline(_ pts: [SIMD3<Float>], closed: Bool = false,
                               to vertices: inout [Vertex], indices: inout [UInt32]) {
        guard pts.count >= 2 else { return }
        let count = closed ? pts.count : pts.count - 1
        for i in 0..<count {
            let p = pts[i]
            let q = pts[(i + 1) % pts.count]
            if simd_distance(p, q) < 1e-7 { continue }
            appendSegment(p, q, to: &vertices, indices: &indices)
        }
    }

    /// Un solo segmento P→Q como cinta (P y Q se guardan mutuamente en normal).
    static func appendSegment(_ p: SIMD3<Float>, _ q: SIMD3<Float>,
                              to vertices: inout [Vertex], indices: inout [UInt32]) {
        let base = UInt32(vertices.count)
        // 4 vértices: (P,-1) (P,+1) (Q,-1) (Q,+1). normal = el OTRO extremo.
        vertices.append(Vertex(position: p, normal: q, uv: SIMD2(-1, 0)))
        vertices.append(Vertex(position: p, normal: q, uv: SIMD2( 1, 0)))
        vertices.append(Vertex(position: q, normal: p, uv: SIMD2(-1, 0)))
        vertices.append(Vertex(position: q, normal: p, uv: SIMD2( 1, 0)))
        indices.append(contentsOf: [
            base, base + 1, base + 2,
            base + 1, base + 3, base + 2
        ])
    }

    /// Punto/vértice como pequeño DISCO encarado a cámara (2 triángulos). El shader
    /// lo recorta a círculo AA de tamaño constante en píxeles. Codificación para
    /// puntos (independiente de la cámara, siempre un cuadrado sólido):
    ///   position = p · normal.x = esquina en Y [-1,+1] · uv.x = esquina en X [-1,+1]
    ///   · uv.y = 1 (marca de punto). El shader expande en los ejes de PANTALLA.
    static func appendPointDisc(at p: SIMD3<Float>,
                                to vertices: inout [Vertex], indices: inout [UInt32]) {
        let base = UInt32(vertices.count)
        // 4 esquinas de un quad: (X,Y) ∈ {-1,+1}². normal.x lleva la esquina en Y.
        let corners: [(Float, Float)] = [(-1, -1), (1, -1), (-1, 1), (1, 1)]
        for (cx, cy) in corners {
            vertices.append(Vertex(position: p,
                                   normal: SIMD3<Float>(cy, 0, 0),
                                   uv: SIMD2<Float>(cx, 1)))
        }
        indices.append(contentsOf: [
            base, base + 1, base + 2,
            base + 1, base + 3, base + 2
        ])
    }
}

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
        // NDC en [-1,1]. El aspect NO va aquí: se aplica UNA sola vez vía halfW.
        // Antes se multiplicaba en ndc.x Y en halfW (→ aspect²) y el toque caía
        // desviado horizontalmente, peor hacia los bordes. Ahora el rayo coincide
        // exacto con projectionMatrix (x = y/aspect) del render → el punto aparece
        // donde tocas y la selección 3D acierta.
        let ndc = SIMD2<Float>(
            2 * Float(screenPoint.x) / Float(viewSize.width) - 1,
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

    /// Malla de highlight para una arista: LÍNEA nítida (cinta plana AA) a lo largo
    /// de la curva, NO un tubo 3D. El render la dibuja con el pipeline de línea en
    /// BRASA (selección activa, Acero & Brasa). El grosor es en píxeles (shader), un
    /// poco mayor que el de las aristas en reposo para que la selección resalte.
    /// `radius` se conserva por compatibilidad de firma; ya no define geometría.
    static func highlightTube(shape: CADShape, edgeIndex: Int,
                              radius: Float = 0.012) -> Mesh? {
        guard let pts = polyline(of: shape, edgeIndex: edgeIndex), pts.count >= 2 else {
            return nil
        }
        var vertices: [Vertex] = []
        var indices: [UInt32] = []
        LineRibbonBuilder.appendPolyline(pts, to: &vertices, indices: &indices)
        return vertices.isEmpty ? nil : Mesh(vertices: vertices, indices: indices)
    }
}

// MARK: - Picker de vértices B-rep

/// Del punto de impacto al VÉRTICE B-rep más cercano: los "puntos reales" donde
/// confluyen las aristas. Base de la selección de puntos, el snap de medición y el
/// mover sub-elementos. OCCTSwift @v1.8.8 NO expone `Shape.vertices()` verificado,
/// así que los vértices se derivan de los ENDPOINTS de las aristas (API `points`
/// ya verificada), deduplicados por proximidad: dos aristas que se encuentran
/// comparten exactamente un punto → una esquina.
enum BRepVertexPicker {

    /// Vértices únicos del shape = endpoints de todas las aristas, deduplicados.
    /// Orden estable (primer avistamiento) para que los índices sean reproducibles.
    static func vertices(of shape: CADShape, tolerance: Float = 1e-4) -> [SIMD3<Float>] {
        var result: [SIMD3<Float>] = []
        for edge in shape.edges() {
            for p in edge.points(count: 2) {
                let v = SIMD3<Float>(Float(p.x), Float(p.y), Float(p.z))
                if !result.contains(where: { simd_distance($0, v) <= tolerance }) {
                    result.append(v)
                }
            }
        }
        return result
    }

    /// Índice del vértice más cercano al punto. `maxDistance` MÁS apretado que el de
    /// arista: un punto es el objetivo más fino y solo gana con un toque claramente
    /// sobre la esquina.
    static func vertexIndex(of shape: CADShape, nearest point: SIMD3<Float>,
                            maxDistance: Float = 0.03) -> Int? {
        let verts = vertices(of: shape)
        var bestIndex: Int?
        var bestDistance = Float.greatestFiniteMagnitude
        for (i, v) in verts.enumerated() {
            let d = simd_distance(v, point)
            if d < bestDistance {
                bestDistance = d
                bestIndex = i
            }
        }
        return bestDistance <= maxDistance ? bestIndex : nil
    }

    /// Posición del vértice `index` (o nil si fuera de rango).
    static func position(of shape: CADShape, vertexIndex index: Int) -> SIMD3<Float>? {
        let verts = vertices(of: shape)
        guard index >= 0, index < verts.count else { return nil }
        return verts[index]
    }

    /// Malla de highlight de un punto: DISCO plano encarado a cámara (2 triángulos),
    /// NO un octaedro/blob 3D gordo. El render lo dibuja con el pipeline de línea que
    /// lo recorta a un círculo AA nítido de tamaño constante en píxeles. `size` se
    /// conserva por compatibilidad; el tamaño real lo fija el shader.
    static func highlightDot(at position: SIMD3<Float>, size: Float = 0.03) -> Mesh {
        var vertices: [Vertex] = []
        var indices: [UInt32] = []
        LineRibbonBuilder.appendPointDisc(at: position, to: &vertices, indices: &indices)
        return Mesh(vertices: vertices, indices: indices)
    }
}
