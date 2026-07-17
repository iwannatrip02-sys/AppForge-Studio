import Foundation

/// Región cerrada del sketch (área sombreada/extruible).
public struct SketchRegion: Sendable {
    /// Contorno como polígono (CCW, sin repetir el primer vértice al final).
    public let polygon: [Vec2]
    /// Área firmada (positiva, CCW).
    public let area: Double
    public let boundingBox: BBox2

    public init(polygon: [Vec2], area: Double) {
        self.polygon = polygon
        self.area = area
        self.boundingBox = BBox2(of: polygon)
    }

    /// ¿El punto cae dentro? (ray casting)
    public func contains(_ p: Vec2) -> Bool {
        guard boundingBox.contains(p) else { return false }
        var inside = false
        var j = polygon.count - 1
        for i in 0..<polygon.count {
            let a = polygon[i], b = polygon[j]
            if (a.y > p.y) != (b.y > p.y) {
                let xCross = a.x + (p.y - a.y) / (b.y - a.y) * (b.x - a.x)
                if p.x < xCross { inside.toggle() }
            }
            j = i
        }
        return inside
    }

    public var centroid: Vec2 {
        guard !polygon.isEmpty else { return .zero }
        return polygon.reduce(Vec2.zero, +) / Double(polygon.count)
    }
}

/// Detección de regiones: arreglo plano POLIGONAL. Todas las curvas se
/// discretizan, los segmentos se parten en cada cruce, los nodos se sueldan
/// por tolerancia, y las caras acotadas se extraen recorriendo semi-aristas
/// (en cada nodo se toma la siguiente arista en orden CCW — caras interiores
/// salen CCW con área positiva). Cubre líneas, arcos, círculos y splines de
/// manera uniforme; el polígono resultante alimenta directamente la extrusión.
public enum RegionFinder {

    public static func regions(in model: SketchModel,
                               maxDeviation: Double = 2e-3,
                               weldTolerance: Double? = nil) -> [SketchRegion] {
        let weld = weldTolerance ?? max(model.mergeTolerance, maxDeviation)
        // 1. Sopa de segmentos de todas las curvas discretizadas. La geometría
        // de CONSTRUCCIÓN se omite: es helper (snappable/seleccionable) pero no
        // debe cerrar regiones ni aportar aristas al perfil extruible.
        var segments: [(Vec2, Vec2)] = []
        for curve in model.orderedCurves where !curve.isConstruction {
            guard let g = CurveGeometry.resolve(curve, in: model) else { continue }
            let poly = g.discretize(maxDeviation: maxDeviation)
            for i in 0..<(poly.count - 1) where poly[i].distance(to: poly[i + 1]) > weld * 0.5 {
                segments.append((poly[i], poly[i + 1]))
            }
        }
        guard segments.count >= 3 else { return [] }

        // 2. Partir cada segmento en sus cruces con los demás
        segments = split(segments: segments, weld: weld)

        // 3. Grafo con nodos soldados
        var graph = WeldedGraph(tolerance: weld)
        for (a, b) in segments { graph.addEdge(a, b) }

        // 4. Caras por recorrido de semi-aristas
        let faces = graph.boundedFaces()
        return faces
            .filter { $0.area > weld * weld * 4 } // descartar esquirlas numéricas
            .map { SketchRegion(polygon: $0.polygon, area: $0.area) }
            .sorted { $0.area > $1.area }
    }

    /// Región que contiene el punto (la MÁS PEQUEÑA que lo contenga: si tocas
    /// dentro del círculo que está dentro del rect, quieres el círculo).
    public static func region(at p: Vec2, in regions: [SketchRegion]) -> SketchRegion? {
        regions.filter { $0.contains(p) }.min { $0.area < $1.area }
    }

    // MARK: - Particionado

    static func split(segments: [(Vec2, Vec2)], weld: Double) -> [(Vec2, Vec2)] {
        var result: [(Vec2, Vec2)] = []
        for (i, seg) in segments.enumerated() {
            var cuts: [Double] = [] // parámetros t sobre el segmento
            let dir = seg.1 - seg.0
            let len2 = dir.lengthSquared
            guard len2 > 1e-18 else { continue }
            for (j, other) in segments.enumerated() where j != i {
                if let x = Intersections.segmentSegment(seg.0, seg.1, other.0, other.1) {
                    let t = (x - seg.0).dot(dir) / len2
                    if t > 1e-9 && t < 1 - 1e-9 { cuts.append(t) }
                }
            }
            if cuts.isEmpty {
                result.append(seg)
            } else {
                cuts.sort()
                var prev = seg.0
                for t in cuts {
                    let q = seg.0 + dir * t
                    if prev.distance(to: q) > weld * 0.5 { result.append((prev, q)) }
                    prev = q
                }
                if prev.distance(to: seg.1) > weld * 0.5 { result.append((prev, seg.1)) }
            }
        }
        return result
    }
}

/// Grafo plano con soldadura de nodos por tolerancia y extracción de caras.
struct WeldedGraph {
    let tolerance: Double
    private(set) var nodes: [Vec2] = []
    /// Adyacencia: por nodo, índices de nodos vecinos (sin duplicados).
    private(set) var adjacency: [[Int]] = []
    /// Rejilla de hashing para soldar rápido.
    private var buckets: [Int64: [Int]] = [:]

    init(tolerance: Double) {
        self.tolerance = max(tolerance, 1e-12)
    }

    private func key(_ p: Vec2) -> Int64 {
        let s = 1.0 / (tolerance * 2)
        let ix = Int64((p.x * s).rounded())
        let iy = Int64((p.y * s).rounded())
        return ix &* 0x9E3779B9 &+ iy
    }

    mutating func weld(_ p: Vec2) -> Int {
        // Buscar en el bucket propio y los 8 vecinos
        let s = 1.0 / (tolerance * 2)
        let ix = Int64((p.x * s).rounded())
        let iy = Int64((p.y * s).rounded())
        for dx: Int64 in -1...1 {
            for dy: Int64 in -1...1 {
                let k = (ix + dx) &* 0x9E3779B9 &+ (iy + dy)
                for idx in buckets[k] ?? [] where nodes[idx].distance(to: p) <= tolerance {
                    return idx
                }
            }
        }
        let idx = nodes.count
        nodes.append(p)
        adjacency.append([])
        buckets[key(p), default: []].append(idx)
        return idx
    }

    mutating func addEdge(_ a: Vec2, _ b: Vec2) {
        let ia = weld(a), ib = weld(b)
        guard ia != ib else { return }
        if !adjacency[ia].contains(ib) { adjacency[ia].append(ib) }
        if !adjacency[ib].contains(ia) { adjacency[ib].append(ia) }
    }

    struct Face {
        let polygon: [Vec2]
        let area: Double
    }

    /// Caras acotadas: para cada semi-arista no visitada se recorre eligiendo
    /// en cada nodo la siguiente arista en orden CCW después de la de llegada
    /// (regla del "giro más a la derecha") — las caras interiores salen con
    /// área positiva; la cara exterior sale negativa y se filtra.
    func boundedFaces() -> [Face] {
        // Orden CCW de vecinos por nodo
        var sorted: [[Int]] = []
        sorted.reserveCapacity(nodes.count)
        for (i, neigh) in adjacency.enumerated() {
            sorted.append(neigh.sorted {
                (nodes[$0] - nodes[i]).angle < (nodes[$1] - nodes[i]).angle
            })
        }

        var visited = Set<Int64>() // semi-arista (from,to) empaquetada
        func pack(_ a: Int, _ b: Int) -> Int64 { Int64(a) << 32 | Int64(UInt32(bitPattern: Int32(b))) }

        var faces: [Face] = []
        for start in 0..<nodes.count {
            for next in sorted[start] {
                if visited.contains(pack(start, next)) { continue }
                // Recorrer la cara
                var polygon: [Int] = []
                var from = start
                var to = next
                var steps = 0
                let maxSteps = adjacency.reduce(0) { $0 + $1.count } + 4
                while steps <= maxSteps {
                    visited.insert(pack(from, to))
                    polygon.append(from)
                    // En `to`, la arista de llegada es (from→to); la siguiente
                    // de la cara es la ANTERIOR a la inversa (to→from) en orden
                    // CCW — el "giro más cerrado a favor de las manecillas".
                    // Con grado 2 ambas reglas coinciden; con cruces (grado 3+)
                    // tomar la siguiente fusionaba caras en la unión.
                    let neighbors = sorted[to]
                    guard let idx = neighbors.firstIndex(of: from) else { break }
                    let nextNeighbor = neighbors[(idx - 1 + neighbors.count) % neighbors.count]
                    from = to
                    to = nextNeighbor
                    steps += 1
                    if from == start && to == next { break } // cara cerrada
                }
                guard steps <= maxSteps, polygon.count >= 3 else { continue }
                // Área firmada (shoelace)
                var area = 0.0
                for k in 0..<polygon.count {
                    let p1 = nodes[polygon[k]]
                    let p2 = nodes[polygon[(k + 1) % polygon.count]]
                    area += p1.cross(p2)
                }
                area /= 2
                if area > 0 {
                    faces.append(Face(polygon: polygon.map { nodes[$0] }, area: area))
                }
            }
        }
        return faces
    }
}
