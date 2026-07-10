import Foundation
import simd
import OCCTSwift
import OSLog

private let logger = Logger(subsystem: "com.appforgestudio", category: "SectionPlane")

// MARK: - Plano de Sección

/// Un plano de sección (clipping plane) que corta la geometría B-rep
/// para mostrar el interior. Múltiples planos pueden estar activos (máx 3).
/// El plano se define por un punto de origen y una normal.
struct SectionPlane: Identifiable, Equatable {
    let id: UUID
    var origin: SIMD3<Float>    // Punto por donde pasa el plano
    var normal: SIMD3<Float>    // Dirección normal (hacia dónde se corta)
    var isActive: Bool = true
    /// Color del plano en la UI
    var color: SIMD4<Float> = SIMD4<Float>(0.3, 0.7, 1.0, 0.4)
    /// Offset desde el origen a lo largo de la normal
    var offset: Float = 0

    init(id: UUID = UUID(),
         origin: SIMD3<Float> = .zero,
         normal: SIMD3<Float> = SIMD3<Float>(0, 1, 0)) {
        self.id = id
        self.origin = origin
        self.normal = simd_normalize(normal)
    }

    /// Ecuación del plano: dot(normal, P - origin) + offset = 0
    func signedDistance(to point: SIMD3<Float>) -> Float {
        simd_dot(normal, point - origin) + offset
    }

    /// Intersección del plano con un segmento
    func intersectSegment(_ a: SIMD3<Float>, _ b: SIMD3<Float>) -> SIMD3<Float>? {
        let da = signedDistance(to: a)
        let db = signedDistance(to: b)
        if da * db > 0 { return nil }  // mismo lado
        if abs(da - db) < 1e-10 { return nil }
        let t = da / (da - db)
        return a + (b - a) * t
    }

    /// Genera una malla de visualización (cuadro translúcido)
    func visualizationMesh(size: Float = 10) -> Mesh {
        // Base ortonormal en el plano
        let ref: SIMD3<Float> = abs(normal.y) < 0.99
            ? SIMD3<Float>(0, 1, 0)
            : SIMD3<Float>(1, 0, 0)
        let u = simd_normalize(simd_cross(normal, ref)) * size * 0.5
        let v = simd_normalize(simd_cross(normal, u)) * size * 0.5

        let o = origin + normal * offset
        let corners: [SIMD3<Float>] = [
            o - u - v, o + u - v, o + u + v, o - u + v
        ]

        var vertices: [Vertex] = []
        var indices: [UInt32] = []

        // Dos triángulos para el cuadro
        for i in 0..<4 {
            vertices.append(Vertex(position: corners[i], normal: normal, uv: .zero))
        }
        indices = [0, 1, 2, 0, 2, 3]

        // Borde del cuadro (tubos finos)
        let borderBase = UInt32(vertices.count)
        for i in 0..<4 {
            let p0 = corners[i]
            let p1 = corners[(i + 1) % 4]
            GizmoBuilder.appendTube(
                polyline: [p0, p1], radius: 0.015,
                to: &vertices, indices: &indices
            )
        }

        return Mesh(vertices: vertices, indices: indices)
    }
}

// MARK: - Sección de geometría B-rep

/// Resultado de cortar un shape B-rep con un plano de sección
struct SectionResult {
    /// Puntos 3D del contorno de la sección (polilínea cerrada)
    var contourPoints: [SIMD3<Float>]
    /// Mesh de relleno de la cara de sección (para visualización)
    var fillMesh: Mesh?
    /// Borde de la sección (tubo fino para visibilidad)
    var edgeMesh: Mesh?
    /// Área de la sección transversal (mm²)
    var area: Double
}

// MARK: - Motor de Plano de Sección

/// Administra planos de sección y genera mallas de corte para visualización.
@MainActor
final class SectionPlaneManager: ObservableObject {
    @Published var planes: [SectionPlane] = []
    @Published var activePlaneCount: Int = 0
    /// Resultados de sección por plano activo
    @Published var sectionResults: [UUID: SectionResult] = [:]

    private let maxPlanes = 3

    // MARK: - CRUD

    func addPlane(origin: SIMD3<Float> = .zero,
                  normal: SIMD3<Float> = SIMD3<Float>(0, 1, 0)) -> SectionPlane? {
        guard planes.count < maxPlanes else {
            logger.warning("SectionPlane: máximo \(maxPlanes) planos alcanzado")
            return nil
        }
        let plane = SectionPlane(origin: origin, normal: normal)
        planes.append(plane)
        activePlaneCount = planes.filter(\.isActive).count
        return plane
    }

    func removePlane(id: UUID) {
        planes.removeAll { $0.id == id }
        sectionResults.removeValue(forKey: id)
        activePlaneCount = planes.filter(\.isActive).count
    }

    func togglePlane(id: UUID) {
        guard let idx = planes.firstIndex(where: { $0.id == id }) else { return }
        planes[idx].isActive.toggle()
        if !planes[idx].isActive {
            sectionResults.removeValue(forKey: id)
        }
        activePlaneCount = planes.filter(\.isActive).count
    }

    func updatePlane(id: UUID, origin: SIMD3<Float>? = nil,
                     normal: SIMD3<Float>? = nil, offset: Float? = nil) {
        guard let idx = planes.firstIndex(where: { $0.id == id }) else { return }
        if let o = origin { planes[idx].origin = o }
        if let n = normal { planes[idx].normal = simd_normalize(n) }
        if let off = offset { planes[idx].offset = off }
        // Invalidar resultado cacheado
        sectionResults.removeValue(forKey: id)
    }

    func clearAll() {
        planes.removeAll()
        sectionResults.removeAll()
        activePlaneCount = 0
    }

    // MARK: - Computación de sección

    /// Calcula la sección de un shape B-rep con un plano.
    /// Recorre los triángulos de la malla de display y encuentra intersecciones con el plano.
    func computeSection(shape: CADShape, plane: SectionPlane,
                        displayMesh: Mesh) -> SectionResult {
        var contourPoints: [SIMD3<Float>] = []
        var edgeSet = Set<String>()

        // Encontrar aristas de intersección plano-triángulo
        var j = 0
        while j + 2 < displayMesh.indices.count {
            let i0 = Int(displayMesh.indices[j])
            let i1 = Int(displayMesh.indices[j + 1])
            let i2 = Int(displayMesh.indices[j + 2])
            j += 3
            guard i0 < displayMesh.vertices.count,
                  i1 < displayMesh.vertices.count,
                  i2 < displayMesh.vertices.count else { continue }

            let p0 = displayMesh.vertices[i0].position
            let p1 = displayMesh.vertices[i1].position
            let p2 = displayMesh.vertices[i2].position

            let d0 = plane.signedDistance(to: p0)
            let d1 = plane.signedDistance(to: p1)
            let d2 = plane.signedDistance(to: p2)

            // Solo triángulos que cruzan el plano
            let above = (d0 >= 0 ? 1 : 0) + (d1 >= 0 ? 1 : 0) + (d2 >= 0 ? 1 : 0)
            guard above >= 1 && above <= 2 else { continue }

            var intersections: [SIMD3<Float>] = []
            if let hit = plane.intersectSegment(p0, p1) {
                intersections.append(hit)
            }
            if let hit = plane.intersectSegment(p1, p2) {
                intersections.append(hit)
            }
            if let hit = plane.intersectSegment(p2, p0) {
                intersections.append(hit)
            }

            if intersections.count == 2 {
                let key1 = "\(intersections[0])-\(intersections[1])"
                let key2 = "\(intersections[1])-\(intersections[0])"
                if !edgeSet.contains(key1) && !edgeSet.contains(key2) {
                    edgeSet.insert(key1)
                    contourPoints.append(intersections[0])
                    contourPoints.append(intersections[1])
                }
            }
        }

        // Ordenar puntos para formar polilínea (por proximidad)
        var ordered: [SIMD3<Float>] = []
        if !contourPoints.isEmpty {
            var remaining = contourPoints
            ordered.append(remaining.removeFirst())
            while !remaining.isEmpty {
                let last = ordered.last!
                var bestIdx: Int?
                var bestDist: Float = .greatestFiniteMagnitude
                for (i, p) in remaining.enumerated() {
                    let dist = simd_distance(last, p)
                    if dist < bestDist { bestDist = dist; bestIdx = i }
                }
                if let idx = bestIdx, bestDist < 0.5 {
                    ordered.append(remaining.remove(at: idx))
                } else {
                    break
                }
            }
            // Cerrar si están cerca
            if let first = ordered.first, let last = ordered.last,
               simd_distance(first, last) < 0.1 {
                // Ya está cerrado
            }
        }

        // Calcular área (fórmula de cordón de zapato en 3D, proyectada al plano)
        var area: Double = 0
        if ordered.count >= 3 {
            let n = plane.normal
            let ref: SIMD3<Float> = abs(n.y) < 0.99 ? SIMD3<Float>(0, 1, 0) : SIMD3<Float>(1, 0, 0)
            let u = simd_normalize(simd_cross(n, ref))
            let v = simd_cross(n, u)

            for i in 0..<ordered.count {
                let j = (i + 1) % ordered.count
                let pi = ordered[i]
                let pj = ordered[j]
                let ui = simd_dot(pi, u)
                let vi = simd_dot(pi, v)
                let uj = simd_dot(pj, u)
                let vj = simd_dot(pj, v)
                area += Double(ui * vj - uj * vi)
            }
            area = abs(area) * 0.5
        }

        // Mesh de relleno: triangulación por abanico desde centroide
        var fillMesh: Mesh?
        if ordered.count >= 3 {
            let centroid = ordered.reduce(.zero, +) / Float(ordered.count)
            var fillVerts: [Vertex] = [Vertex(position: centroid, normal: plane.normal, uv: .zero)]
            for p in ordered {
                fillVerts.append(Vertex(position: p, normal: plane.normal, uv: .zero))
            }
            var fillIndices: [UInt32] = []
            for i in 0..<ordered.count {
                fillIndices.append(0)
                fillIndices.append(UInt32(i + 1))
                fillIndices.append(UInt32((i + 1) % ordered.count + 1))
            }
            fillMesh = Mesh(vertices: fillVerts, indices: fillIndices)
        }

        // Mesh de borde (tubo fino)
        var edgeMesh: Mesh?
        if ordered.count >= 2 {
            var edgeVerts: [Vertex] = []
            var edgeIndices: [UInt32] = []
            var pts = ordered
            if let first = pts.first { pts.append(first) }
            GizmoBuilder.appendTube(polyline: pts, radius: 0.012,
                                    to: &edgeVerts, indices: &edgeIndices)
            edgeMesh = edgeVerts.isEmpty ? nil : Mesh(vertices: edgeVerts, indices: edgeIndices)
        }

        return SectionResult(
            contourPoints: ordered,
            fillMesh: fillMesh,
            edgeMesh: edgeMesh,
            area: area
        )
    }

    /// Actualiza todas las secciones activas para un modelo
    func updateAllSections(for model: Model) {
        guard let shape = model.cadShape,
              let displayMesh = model.meshes.first else { return }

        for plane in planes where plane.isActive {
            let result = computeSection(shape: shape, plane: plane,
                                        displayMesh: displayMesh)
            sectionResults[plane.id] = result
        }
    }

    /// Genera modelos overlay para visualizar planos + secciones
    func overlayModels() -> [Model] {
        var models: [Model] = []

        for plane in planes {
            // Plano translúcido
            let vizModel = Model(name: "__sectionPlane_\(plane.id)")
            vizModel.meshes = [plane.visualizationMesh()]
            vizModel.color = plane.color
            vizModel.isVisible = plane.isActive
            models.append(vizModel)

            // Relleno de sección
            if let result = sectionResults[plane.id], plane.isActive {
                if let fill = result.fillMesh {
                    let fillModel = Model(name: "__sectionFill_\(plane.id)")
                    fillModel.meshes = [fill]
                    fillModel.color = SIMD4<Float>(1.0, 0.48, 0.27, 0.5)  // brasa translúcido
                    models.append(fillModel)
                }
                if let edge = result.edgeMesh {
                    let edgeModel = Model(name: "__sectionEdge_\(plane.id)")
                    edgeModel.meshes = [edge]
                    edgeModel.color = SIMD4<Float>(1.0, 0.48, 0.27, 0.9)
                    models.append(edgeModel)
                }
            }
        }

        return models
    }
}
