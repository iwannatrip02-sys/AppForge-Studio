import Foundation

/// Tramo del contorno de una región que CONSERVA la identidad de la curva
/// original: qué curva es y qué intervalo de su parámetro se recorre.
///
/// `tStart > tEnd` significa que la cara recorre la curva en sentido inverso al
/// de su definición. Un círculo recorrido entero es `tStart: 0, tEnd: 1`.
///
/// Sin esto, el contorno de una región es solo un polígono y la extrusión de un
/// círculo produce un prisma de ~50 caras planas en vez de un cilindro real.
public struct RegionEdge: Sendable, Equatable {
    public let curveID: CurveID
    public let tStart: Double
    public let tEnd: Double

    public init(curveID: CurveID, tStart: Double, tEnd: Double) {
        self.curveID = curveID
        self.tStart = tStart
        self.tEnd = tEnd
    }

    /// Se recorre en sentido inverso al de definición de la curva.
    public var isReversed: Bool { tEnd < tStart }

    /// Fracción de la curva cubierta por el tramo (1 = la curva entera).
    public var sweep: Double { abs(tEnd - tStart) }
}

/// Región cerrada del sketch (área sombreada/extruible).
public struct SketchRegion: Sendable {
    /// Contorno como polígono (CCW, sin repetir el primer vértice al final).
    public let polygon: [Vec2]
    /// Área firmada (positiva, CCW).
    public let area: Double
    public let boundingBox: BBox2
    /// El mismo contorno pero con la IDENTIDAD de las curvas conservada, en el
    /// orden del recorrido. Vacío cuando no se pudo rastrear la procedencia —
    /// el consumidor cae entonces al polígono (correcto, solo que facetado).
    public let boundary: [RegionEdge]

    public init(polygon: [Vec2], area: Double, boundary: [RegionEdge] = []) {
        self.polygon = polygon
        self.area = area
        self.boundingBox = BBox2(of: polygon)
        self.boundary = boundary
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

/// Segmento discretizado que RECUERDA de qué curva salió y en qué intervalo de
/// parámetro. La procedencia sobrevive al partido por intersecciones y al
/// recorrido de caras, y es lo que permite reconstruir el perfil analítico.
struct ProvSegment {
    var a: Vec2
    var b: Vec2
    var curveID: CurveID
    var ta: Double
    var tb: Double
}

/// Detección de regiones: arreglo plano POLIGONAL. Todas las curvas se
/// discretizan, los segmentos se parten en cada cruce, los nodos se sueldan
/// por tolerancia, y las caras acotadas se extraen recorriendo semi-aristas
/// (en cada nodo se toma la siguiente arista en orden CCW — caras interiores
/// salen CCW con área positiva). Cubre líneas, arcos, círculos y splines de
/// manera uniforme.
///
/// El polígono resultante alimenta el hit-testing y el sombreado; para la
/// geometría B-rep se usa `SketchRegion.boundary`, que conserva las curvas
/// originales (un círculo vuelve a ser un círculo).
public enum RegionFinder {

    public static func regions(in model: SketchModel,
                               maxDeviation: Double = 2e-3,
                               weldTolerance: Double? = nil) -> [SketchRegion] {
        let weld = weldTolerance ?? max(model.mergeTolerance, maxDeviation)
        // 1. Sopa de segmentos de todas las curvas discretizadas, cada uno con
        // su procedencia. La geometría de CONSTRUCCIÓN se omite: es helper
        // (snappable/seleccionable) pero no debe cerrar regiones ni aportar
        // aristas al perfil extruible.
        var segments: [ProvSegment] = []
        for curve in model.orderedCurves where !curve.isConstruction {
            guard let g = CurveGeometry.resolve(curve, in: model) else { continue }
            let poly = g.discretizeWithParams(maxDeviation: maxDeviation)
            guard poly.count >= 2 else { continue }
            for i in 0..<(poly.count - 1)
            where poly[i].point.distance(to: poly[i + 1].point) > weld * 0.5 {
                segments.append(ProvSegment(a: poly[i].point, b: poly[i + 1].point,
                                            curveID: curve.id,
                                            ta: poly[i].t, tb: poly[i + 1].t))
            }
        }
        guard segments.count >= 3 else { return [] }

        // 2. Partir cada segmento en sus cruces con los demás
        segments = split(segments: segments, weld: weld)

        // 3. Grafo con nodos soldados
        var graph = WeldedGraph(tolerance: weld)
        for s in segments { graph.addEdge(s) }

        // 4. Caras por recorrido de semi-aristas
        let faces = graph.boundedFaces()
        return faces
            .filter { $0.area > weld * weld * 4 } // descartar esquirlas numéricas
            .map { SketchRegion(polygon: $0.polygon, area: $0.area, boundary: $0.boundary) }
            .sorted { $0.area > $1.area }
    }

    /// Región que contiene el punto (la MÁS PEQUEÑA que lo contenga: si tocas
    /// dentro del círculo que está dentro del rect, quieres el círculo).
    public static func region(at p: Vec2, in regions: [SketchRegion]) -> SketchRegion? {
        regions.filter { $0.contains(p) }.min { $0.area < $1.area }
    }

    // MARK: - Particionado

    static func split(segments: [ProvSegment], weld: Double) -> [ProvSegment] {
        var result: [ProvSegment] = []
        for (i, seg) in segments.enumerated() {
            var cuts: [Double] = [] // parámetros t sobre el segmento
            let dir = seg.b - seg.a
            let len2 = dir.lengthSquared
            guard len2 > 1e-18 else { continue }
            for (j, other) in segments.enumerated() where j != i {
                if let x = Intersections.segmentSegment(seg.a, seg.b, other.a, other.b) {
                    let t = (x - seg.a).dot(dir) / len2
                    if t > 1e-9 && t < 1 - 1e-9 { cuts.append(t) }
                }
            }
            if cuts.isEmpty {
                result.append(seg)
                continue
            }
            cuts.sort()
            // El parámetro de la CURVA se interpola con la misma fracción con
            // que se corta el segmento: dentro de un paso de discretización el
            // error es despreciable y los tramos contiguos se vuelven a fundir.
            func curveT(_ u: Double) -> Double { seg.ta + (seg.tb - seg.ta) * u }
            var prev = seg.a
            var prevU = 0.0
            for u in cuts {
                let q = seg.a + dir * u
                if prev.distance(to: q) > weld * 0.5 {
                    result.append(ProvSegment(a: prev, b: q, curveID: seg.curveID,
                                              ta: curveT(prevU), tb: curveT(u)))
                }
                prev = q
                prevU = u
            }
            if prev.distance(to: seg.b) > weld * 0.5 {
                result.append(ProvSegment(a: prev, b: seg.b, curveID: seg.curveID,
                                          ta: curveT(prevU), tb: seg.tb))
            }
        }
        return result
    }

    // MARK: - Fusión de tramos contiguos

    /// Une tramos consecutivos de la MISMA curva en un solo `RegionEdge`: los
    /// ~50 micro-tramos en que se discretizó un círculo vuelven a ser UN círculo.
    static func mergeRuns(_ steps: [RegionEdge], epsilon: Double = 1e-9) -> [RegionEdge] {
        guard let first = steps.first else { return [] }

        // Caso dominante: TODO el contorno es una sola curva cerrada (un
        // círculo suelto). El recorrido puede arrancar en cualquier punto del
        // aro, así que no hay corte donde partir — se emite la curva entera.
        if steps.allSatisfy({ $0.curveID == first.curveID }) {
            let forward = steps.filter { $0.tEnd > $0.tStart }.count * 2 >= steps.count
            return [RegionEdge(curveID: first.curveID,
                               tStart: forward ? 0 : 1,
                               tEnd: forward ? 1 : 0)]
        }

        // Rotar para empezar donde arranca una curva (existe tal corte porque
        // hay ≥2 IDs distintos), si no el primer y el último run se partirían.
        var ordered = steps
        let n = steps.count
        if let cut = (0..<n).first(where: { steps[$0].curveID != steps[($0 + n - 1) % n].curveID }) {
            ordered = Array(steps[cut...]) + Array(steps[..<cut])
        }

        var runs: [RegionEdge] = []
        for step in ordered {
            if let last = runs.last, last.curveID == step.curveID,
               abs(last.tEnd - step.tStart) < epsilon {
                runs[runs.count - 1] = RegionEdge(curveID: last.curveID,
                                                  tStart: last.tStart,
                                                  tEnd: step.tEnd)
            } else {
                runs.append(step)
            }
        }
        return runs
    }
}

/// Grafo plano con soldadura de nodos por tolerancia y extracción de caras.
struct WeldedGraph {
    let tolerance: Double
    private(set) var nodes: [Vec2] = []
    /// Adyacencia: por nodo, índices de nodos vecinos (sin duplicados).
    private(set) var adjacency: [[Int]] = []
    /// Procedencia por SEMI-ARISTA dirigida (from,to): de qué curva viene y qué
    /// intervalo de parámetro cubre en ese sentido.
    private(set) var provenance: [Int64: RegionEdge] = [:]
    /// Rejilla de hashing para soldar rápido.
    private var buckets: [Int64: [Int]] = [:]

    init(tolerance: Double) {
        self.tolerance = max(tolerance, 1e-12)
    }

    static func pack(_ a: Int, _ b: Int) -> Int64 {
        Int64(a) << 32 | Int64(UInt32(bitPattern: Int32(b)))
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

    mutating func addEdge(_ seg: ProvSegment) {
        let ia = weld(seg.a), ib = weld(seg.b)
        guard ia != ib else { return }
        if !adjacency[ia].contains(ib) { adjacency[ia].append(ib) }
        if !adjacency[ib].contains(ia) { adjacency[ib].append(ia) }
        // La procedencia se guarda en AMBOS sentidos, con el intervalo de
        // parámetro invertido en el sentido contrario.
        provenance[Self.pack(ia, ib)] = RegionEdge(curveID: seg.curveID,
                                                   tStart: seg.ta, tEnd: seg.tb)
        provenance[Self.pack(ib, ia)] = RegionEdge(curveID: seg.curveID,
                                                   tStart: seg.tb, tEnd: seg.ta)
    }

    struct Face {
        let polygon: [Vec2]
        let area: Double
        /// Contorno con procedencia de curvas; vacío si algún tramo no la traía.
        let boundary: [RegionEdge]
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

        var faces: [Face] = []
        for start in 0..<nodes.count {
            for next in sorted[start] {
                if visited.contains(WeldedGraph.pack(start, next)) { continue }
                // Recorrer la cara
                var polygon: [Int] = []
                var steps: [RegionEdge] = []
                var provComplete = true
                var from = start
                var to = next
                var count = 0
                let maxSteps = adjacency.reduce(0) { $0 + $1.count } + 4
                while count <= maxSteps {
                    visited.insert(WeldedGraph.pack(from, to))
                    polygon.append(from)
                    if let p = provenance[WeldedGraph.pack(from, to)] {
                        steps.append(p)
                    } else {
                        provComplete = false
                    }
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
                    count += 1
                    if from == start && to == next { break } // cara cerrada
                }
                guard count <= maxSteps, polygon.count >= 3 else { continue }
                // Área firmada (shoelace)
                var area = 0.0
                for k in 0..<polygon.count {
                    let p1 = nodes[polygon[k]]
                    let p2 = nodes[polygon[(k + 1) % polygon.count]]
                    area += p1.cross(p2)
                }
                area /= 2
                if area > 0 {
                    let boundary = provComplete ? RegionFinder.mergeRuns(steps) : []
                    faces.append(Face(polygon: polygon.map { nodes[$0] },
                                      area: area,
                                      boundary: boundary))
                }
            }
        }
        return faces
    }
}
