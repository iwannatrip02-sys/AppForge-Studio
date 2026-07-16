import Foundation
import simd

// MARK: - Detector de Regiones Cerradas en Sketch 2D

/// Analiza un conjunto de entidades de sketch y detecta regiones cerradas
/// (ciclos en el grafo de líneas). Cada región es un polígono que puede
/// extruirse directamente — el "sombreado mágico" de Shapr3D.
///
/// Algoritmo:
/// 1. Construir grafo no-dirigido de segmentos de línea
/// 2. Encontrar todos los ciclos mínimos (face cycles de planar graph)
/// 3. Para cada ciclo, generar polígono ordenado
/// 4. El polígono se usa para: (a) mesh de relleno sombreado, (b) Wire OCCT para extrusión
struct SketchRegionDetector {

    /// Una región cerrada detectada: polígono ordenado + área + centroide
    struct ClosedRegion: Identifiable {
        let id: UUID
        /// Vértices en orden ( antihorario = exterior, horario = agujero )
        var vertices: [SIMD2<Float>]
        /// Área de la región (positiva = contorno exterior)
        var area: Float
        /// Centroide de la región
        var centroid: SIMD2<Float>
        /// Si es un agujero (área negativa → dentro de otra región)
        var isHole: Bool

        init(id: UUID = UUID(), vertices: [SIMD2<Float>]) {
            self.id = id
            self.vertices = vertices
            self.area = SketchRegionDetector.polygonArea(vertices)
            self.isHole = self.area < 0
            self.centroid = SketchRegionDetector.polygonCentroid(vertices)
        }
    }

    // MARK: - API Pública

    /// Detecta todas las regiones cerradas en una lista de entidades de sketch.
    /// Solo considera líneas (polyline, rect, polygon). Círculos y arcos se discretizan.
    static func detectRegions(in entities: [SketchController.Entity],
                               chain: [SIMD2<Float>] = []) -> [ClosedRegion] {
        var segments: [(SIMD2<Float>, SIMD2<Float>)] = []

        for entity in entities {
            switch entity {
            case .polyline(let pts, let closed):
                for i in 0..<(pts.count - 1) {
                    segments.append((pts[i], pts[i + 1]))
                }
                if closed, let first = pts.first, let last = pts.last {
                    segments.append((last, first))
                }
            case .rect(let a, let b):
                let corners = [a, SIMD2(b.x, a.y), b, SIMD2(a.x, b.y)]
                for i in 0..<4 {
                    segments.append((corners[i], corners[(i + 1) % 4]))
                }
            case .circle(let c, let r):
                segments.append(contentsOf: discretizeCircle(center: c, radius: r, segments: 32))
            case .polygonEnt(let c, let r, let sides):
                let verts = SketchController.Entity.polygonVerts(center: c, radius: r, sides: sides)
                for i in 0..<sides {
                    segments.append((verts[i], verts[(i + 1) % sides]))
                }
            case .spline(let pts):
                for i in 0..<(pts.count - 1) {
                    segments.append((pts[i], pts[i + 1]))
                }
            }
        }

        // Agregar cadena activa (no confirmada aún)
        if chain.count >= 2 {
            for i in 0..<(chain.count - 1) {
                segments.append((chain[i], chain[i + 1]))
            }
        }

        return findClosedRegions(segments: segments)
    }

    /// Genera una malla de relleno para las regiones (triángulos semitransparentes
    /// que se renderizan sobre el plano de sketch para mostrar "esto es un sólido potencial")
    static func fillMesh(for regions: [ClosedRegion],
                          on plane: SketchController.WorkPlane,
                          color: SIMD4<Float> = SIMD4<Float>(1.0, 0.48, 0.27, 0.18)) -> Mesh? {
        var vertices: [Vertex] = []
        var indices: [UInt32] = []
        let offset = plane.normal * 0.001  // evitar z-fighting con el plano

        for region in regions where !region.isHole && region.vertices.count >= 3 {
            let base = UInt32(vertices.count)
            // Triangulación por abanico desde el centroide
            let c3 = plane.origin + plane.u * region.centroid.x + plane.v * region.centroid.y + offset
            vertices.append(Vertex(position: c3, normal: plane.normal, uv: .zero))

            for v in region.vertices {
                let w3 = plane.origin + plane.u * v.x + plane.v * v.y + offset
                vertices.append(Vertex(position: w3, normal: plane.normal, uv: .zero))
            }

            for i in 0..<region.vertices.count {
                indices.append(base)
                indices.append(base + UInt32(i + 1))
                indices.append(base + UInt32((i + 1) % region.vertices.count + 1))
            }
        }

        return vertices.count > 3 ? Mesh(vertices: vertices, indices: indices) : nil
    }

    // MARK: - Algoritmo de detección de ciclos

    private static func findClosedRegions(segments: [(SIMD2<Float>, SIMD2<Float>)]) -> [ClosedRegion] {
        guard segments.count >= 3 else { return [] }

        // Construir grafo de adyacencia (snap de vértices cercanos)
        let tolerance: Float = 0.01
        var nodeMap: [Int: SIMD2<Float>] = [:]  // id → posición unificada
        var adj: [Int: [Int]] = [:]              // id → vecinos
        var edgeSet = Set<String>()               // "idA-idB" normalizado
        var nextID = 0

        func snapID(for p: SIMD2<Float>) -> Int {
            for (id, existing) in nodeMap {
                if simd_distance(existing, p) < tolerance { return id }
            }
            let id = nextID; nextID += 1
            nodeMap[id] = p; adj[id] = []
            return id
        }

        for (a, b) in segments {
            let idA = snapID(for: a)
            let idB = snapID(for: b)
            guard idA != idB else { continue }
            let key = "\(min(idA, idB))-\(max(idA, idB))"
            guard !edgeSet.contains(key) else { continue }
            edgeSet.insert(key)
            adj[idA, default: []].append(idB)
            adj[idB, default: []].append(idA)
        }

        // Encontrar ciclos: DFS desde cada arista, seguir siempre el vecino
        // que gira MÁS a la derecha (para encontrar el ciclo mínimo que encierra
        // cada cara del grafo planar)
        var visitedEdges = Set<String>()
        var regions: [ClosedRegion] = []

        for (u, neighbors) in adj {
            for v in neighbors where u < v {
                let edgeKey = "\(u)-\(v)"
                guard !visitedEdges.contains(edgeKey) else { continue }

                if let cycle = traceCycle(from: v, prev: u, start: u,
                                          adj: adj, nodeMap: nodeMap,
                                          visitedEdges: &visitedEdges) {
                    regions.append(ClosedRegion(vertices: cycle))
                }
            }
        }

        // Ordenar por área (mayor primero), luego filtrar agujeros que están dentro
        return regions.sorted { abs($0.area) > abs($1.area) }
    }

    /// Sigue el borde del ciclo tomando siempre el giro más a la derecha.
    private static func traceCycle(from current: Int, prev: Int, start: Int,
                                    adj: [Int: [Int]],
                                    nodeMap: [Int: SIMD2<Float>],
                                    visitedEdges: inout Set<String>) -> [SIMD2<Float>]? {
        var path: [Int] = [prev, current]
        var cur = current
        var prevNode = prev

        for _ in 0..<500 {  // safety limit
            let neighbors = adj[cur]?.filter { $0 != prevNode } ?? []
            if neighbors.isEmpty { return nil }

            // Elegir vecino con el ángulo más a la derecha
            let curPos = nodeMap[cur]!
            let prevDir = simd_normalize(curPos - nodeMap[prevNode]!)
            var bestNeighbor = neighbors[0]
            var bestAngle: Float = -.pi

            for n in neighbors {
                let dir = simd_normalize(nodeMap[n]! - curPos)
                let cross = prevDir.x * dir.y - prevDir.y * dir.x
                let dot = prevDir.x * dir.x + prevDir.y * dir.y
                var angle = atan2(cross, dot)
                if angle < 0 { angle += 2 * .pi }
                if angle > bestAngle { bestAngle = angle; bestNeighbor = n }
            }

            let edgeKey = "\(min(cur, bestNeighbor))-\(max(cur, bestNeighbor))"
            visitedEdges.insert(edgeKey)

            if bestNeighbor == start { return path.map { nodeMap[$0]! } }
            path.append(bestNeighbor)
            prevNode = cur
            cur = bestNeighbor
        }
        return nil
    }

    // MARK: - Utilidades geométricas

    /// Área de un polígono (fórmula del cordón de zapato).
    /// Positiva = antihorario (contorno exterior), negativa = horario (agujero).
    static func polygonArea(_ vertices: [SIMD2<Float>]) -> Float {
        guard vertices.count >= 3 else { return 0 }
        var area: Float = 0
        for i in 0..<vertices.count {
            let j = (i + 1) % vertices.count
            area += vertices[i].x * vertices[j].y
            area -= vertices[j].x * vertices[i].y
        }
        return area * 0.5
    }

    /// Centroide de un polígono
    static func polygonCentroid(_ vertices: [SIMD2<Float>]) -> SIMD2<Float> {
        guard vertices.count >= 3 else { return vertices.first ?? .zero }
        var sum = SIMD2<Float>.zero
        for v in vertices { sum += v }
        return sum / Float(vertices.count)
    }

    /// ¿El punto `p` está dentro del polígono? (ray-casting par/impar).
    static func polygonContains(_ vertices: [SIMD2<Float>], _ p: SIMD2<Float>) -> Bool {
        guard vertices.count >= 3 else { return false }
        var inside = false
        var j = vertices.count - 1
        for i in 0..<vertices.count {
            let vi = vertices[i], vj = vertices[j]
            if (vi.y > p.y) != (vj.y > p.y) {
                let t = (p.y - vi.y) / (vj.y - vi.y)
                if p.x < vi.x + t * (vj.x - vi.x) { inside.toggle() }
            }
            j = i
        }
        return inside
    }

    /// Discretiza un círculo en segmentos de línea
    static func discretizeCircle(center: SIMD2<Float>, radius: Float,
                                  segments: Int = 32) -> [(SIMD2<Float>, SIMD2<Float>)] {
        var result: [(SIMD2<Float>, SIMD2<Float>)] = []
        for i in 0..<segments {
            let a = Float(i) / Float(segments) * 2 * .pi
            let b = Float(i + 1) / Float(segments) * 2 * .pi
            let pA = center + SIMD2<Float>(cos(a), sin(a)) * radius
            let pB = center + SIMD2<Float>(cos(b), sin(b)) * radius
            result.append((pA, pB))
        }
        return result
    }
}

// MARK: - Visualización de región tocable

/// Genera un overlay que muestra las regiones cerradas como superficies
/// sombreadas y tocables en el viewport.
struct SketchRegionOverlay {
    /// Color de relleno de región (ámbar translúcido — "toca aquí para extruir")
    var fillColor: SIMD4<Float> = SIMD4<Float>(1.0, 0.48, 0.27, 0.15)
    /// Color del borde de la región
    var strokeColor: SIMD4<Float> = SIMD4<Float>(1.0, 0.48, 0.27, 0.6)
    /// Ancho del borde en unidades de mundo
    var strokeWidth: Float = 0.006

    /// Genera meshes de relleno + borde para las regiones detectadas
    func generate(for regions: [SketchRegionDetector.ClosedRegion],
                  on plane: SketchController.WorkPlane) -> (fill: Mesh?, stroke: Mesh?) {
        let fill = SketchRegionDetector.fillMesh(for: regions, on: plane, color: fillColor)

        // Borde: tubos finos sobre el perímetro de cada región
        var strokeVerts: [Vertex] = []
        var strokeIdx: [UInt32] = []
        let offset = plane.normal * 0.002

        for region in regions where !region.isHole && region.vertices.count >= 3 {
            var pts3D: [SIMD3<Float>] = []
            for v in region.vertices {
                pts3D.append(plane.origin + plane.u * v.x + plane.v * v.y + offset)
            }
            // Cerrar el lazo
            if let first = pts3D.first { pts3D.append(first) }
            GizmoBuilder.appendTube(polyline: pts3D, radius: strokeWidth,
                                    to: &strokeVerts, indices: &strokeIdx)
        }

        let stroke = strokeVerts.isEmpty ? nil : Mesh(vertices: strokeVerts, indices: strokeIdx)
        return (fill, stroke)
    }
}
