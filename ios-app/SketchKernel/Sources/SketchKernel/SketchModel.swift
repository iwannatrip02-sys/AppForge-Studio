import Foundation

/// ID de un punto topológico del sketch.
public struct PointID: Hashable, Sendable, Codable {
    public let raw: UUID
    public init() { raw = UUID() }
    public init(raw: UUID) { self.raw = raw }
}

/// ID de una curva del sketch.
public struct CurveID: Hashable, Sendable, Codable {
    public let raw: UUID
    public init() { raw = UUID() }
    public init(raw: UUID) { self.raw = raw }
}

/// Modo de spline — los DOS de Shapr3D.
public enum SplineMode: String, Sendable, Codable {
    /// Pasa POR los puntos (interpolada, Catmull-Rom centrípeta → Bézier).
    case throughPoints
    /// Atraída por el polígono de control (B-spline cúbica sujeta).
    case controlPoints
}

/// Curva del sketch. Los extremos/centros son PUNTOS TOPOLÓGICOS compartidos:
/// una esquina donde se tocan dos líneas es UN solo PointID — mover el punto
/// mueve ambas curvas. Este es el invariante que el sistema viejo no tenía.
public struct SketchCurve: Identifiable, Sendable, Codable {
    public let id: CurveID
    public var kind: Kind
    /// Geometría de CONSTRUCCIÓN (helper): participa en snap y es seleccionable,
    /// pero NO aporta aristas a las regiones cerradas (no genera geometría
    /// extruible). Bit inspirado en `GeometryMode::Construction` de FreeCAD.
    /// Codable retrocompatible: si el JSON viejo no lo trae, decodifica `false`.
    public var isConstruction: Bool = false

    public enum Kind: Sendable, Codable {
        case line(start: PointID, end: PointID)
        /// Arco por centro + extremos. Radio = |start − centro|; `ccw` = sentido
        /// del barrido de start a end. El invariante |end − centro| == radio se
        /// re-impone al editar (fixupArcs).
        case arc(start: PointID, end: PointID, center: PointID, ccw: Bool)
        case circle(center: PointID, radius: Double)
        /// Spline por puntos topológicos (editables/snapeables como cualquier punto).
        case spline(points: [PointID], mode: SplineMode)
    }

    public init(id: CurveID = CurveID(), kind: Kind, isConstruction: Bool = false) {
        self.id = id
        self.kind = kind
        self.isConstruction = isConstruction
    }

    // Codable manual: `isConstruction` decodifica `false` cuando falta la clave
    // (documentos serializados antes de que existiera la geometría de construcción).
    private enum CodingKeys: String, CodingKey {
        case id, kind, isConstruction
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decode(CurveID.self, forKey: .id)
        self.kind = try c.decode(Kind.self, forKey: .kind)
        self.isConstruction = try c.decodeIfPresent(Bool.self, forKey: .isConstruction) ?? false
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(kind, forKey: .kind)
        try c.encode(isConstruction, forKey: .isConstruction)
    }

    /// Puntos topológicos que esta curva referencia.
    public var referencedPoints: [PointID] {
        switch kind {
        case .line(let s, let e): return [s, e]
        case .arc(let s, let e, let c, _): return [s, e, c]
        case .circle(let c, _): return [c]
        case .spline(let pts, _): return pts
        }
    }

    /// Extremos topológicos (para conectividad/regiones). Círculo no tiene.
    public var endpoints: (PointID, PointID)? {
        switch kind {
        case .line(let s, let e): return (s, e)
        case .arc(let s, let e, _, _): return (s, e)
        case .circle: return nil
        case .spline(let pts, _):
            guard let f = pts.first, let l = pts.last else { return nil }
            return (f, l)
        }
    }
}

/// El documento de sketch: puntos compartidos + curvas. Tipo VALOR a propósito:
/// undo/redo = pila de copias del modelo (barato: dicts copy-on-write).
public struct SketchModel: Sendable, Codable {
    public private(set) var positions: [PointID: Vec2] = [:]
    public private(set) var curves: [CurveID: SketchCurve] = [:]
    /// Orden de inserción de curvas (render y recorridos deterministas).
    public private(set) var curveOrder: [CurveID] = []
    /// Puntos sueltos creados explícitamente (herramienta Punto) — sobreviven
    /// aunque ninguna curva los use.
    public private(set) var freePoints: Set<PointID> = []

    /// Tolerancia de FUSIÓN topológica en unidades de sketch: un punto nuevo a
    /// menos de esto de uno existente ES el existente (una esquina = un punto).
    public var mergeTolerance: Double

    public init(mergeTolerance: Double = 1e-4) {
        self.mergeTolerance = mergeTolerance
    }

    // MARK: - Consultas

    public func position(of id: PointID) -> Vec2? { positions[id] }

    public var orderedCurves: [SketchCurve] {
        curveOrder.compactMap { curves[$0] }
    }

    /// Curvas que referencian el punto (para propagar ediciones/borrados).
    public func curvesAttached(to point: PointID) -> [CurveID] {
        curveOrder.filter { curves[$0]?.referencedPoints.contains(point) ?? false }
    }

    /// Punto existente a ≤ tolerance de `p` (el más cercano), o nil.
    public func existingPoint(near p: Vec2, tolerance: Double) -> PointID? {
        var best: (PointID, Double)?
        for (id, pos) in positions {
            let d = pos.distance(to: p)
            if d <= tolerance && d < (best?.1 ?? .infinity) { best = (id, d) }
        }
        return best?.0
    }

    // MARK: - Construcción (todo pasa por la fusión topológica)

    /// EL invariante del kernel: devuelve un punto existente si hay uno a
    /// ≤ mergeTolerance; si no, crea uno nuevo. Toda curva se construye con esto.
    public mutating func addOrMergePoint(at p: Vec2) -> PointID {
        if let existing = existingPoint(near: p, tolerance: mergeTolerance) {
            return existing
        }
        let id = PointID()
        positions[id] = p
        return id
    }

    /// Punto suelto explícito (herramienta Punto).
    @discardableResult
    public mutating func addFreePoint(at p: Vec2) -> PointID {
        let id = addOrMergePoint(at: p)
        freePoints.insert(id)
        return id
    }

    @discardableResult
    public mutating func addLine(from a: Vec2, to b: Vec2) -> CurveID {
        addLine(from: addOrMergePoint(at: a), to: addOrMergePoint(at: b))
    }

    @discardableResult
    public mutating func addLine(from a: PointID, to b: PointID) -> CurveID {
        insert(SketchCurve(kind: .line(start: a, end: b)))
    }

    @discardableResult
    public mutating func addCircle(center: Vec2, radius: Double) -> CurveID {
        let c = addOrMergePoint(at: center)
        return insert(SketchCurve(kind: .circle(center: c, radius: radius)))
    }

    /// Arco centro+extremos. `end` se proyecta sobre el círculo definido por
    /// |start − centro| para garantizar el invariante de radio desde el origen.
    @discardableResult
    public mutating func addArc(center: Vec2, start: Vec2, end: Vec2, ccw: Bool) -> CurveID {
        let cID = addOrMergePoint(at: center)
        let sID = addOrMergePoint(at: start)
        let r = start.distance(to: center)
        let projectedEnd = center + (end - center).normalized * r
        let eID = addOrMergePoint(at: projectedEnd)
        return insert(SketchCurve(kind: .arc(start: sID, end: eID, center: cID, ccw: ccw)))
    }

    @discardableResult
    public mutating func addSpline(through points: [Vec2], mode: SplineMode) -> CurveID {
        let ids = points.map { addOrMergePoint(at: $0) }
        return insert(SketchCurve(kind: .spline(points: ids, mode: mode)))
    }

    @discardableResult
    private mutating func insert(_ curve: SketchCurve) -> CurveID {
        curves[curve.id] = curve
        curveOrder.append(curve.id)
        return curve.id
    }

    // MARK: - Edición

    /// Mueve un punto topológico — TODAS las curvas que lo comparten siguen.
    /// Re-impone el invariante de radio de los arcos afectados.
    public mutating func movePoint(_ id: PointID, to p: Vec2) {
        guard positions[id] != nil else { return }
        positions[id] = p
        fixupArcs(touching: id)
    }

    public mutating func setCircleRadius(_ id: CurveID, radius: Double) {
        guard case .circle(let c, _) = curves[id]?.kind else { return }
        curves[id]?.kind = .circle(center: c, radius: max(1e-9, radius))
    }

    /// Marca/desmarca una curva como geometría de construcción (helper). Las de
    /// construcción no cierran regiones pero siguen snappables y seleccionables.
    public mutating func setConstruction(_ id: CurveID, _ flag: Bool) {
        guard curves[id] != nil else { return }
        curves[id]?.isConstruction = flag
    }

    /// Elimina la curva y recoge los puntos que quedaron huérfanos
    /// (no referenciados por otra curva ni marcados como puntos sueltos).
    public mutating func removeCurve(_ id: CurveID) {
        guard let curve = curves[id] else { return }
        curves[id] = nil
        curveOrder.removeAll { $0 == id }
        for p in curve.referencedPoints where !freePoints.contains(p) {
            if curvesAttached(to: p).isEmpty { positions[p] = nil }
        }
    }

    public mutating func removeFreePoint(_ id: PointID) {
        freePoints.remove(id)
        if curvesAttached(to: id).isEmpty { positions[id] = nil }
    }

    public mutating func removeAll() {
        positions.removeAll()
        curves.removeAll()
        curveOrder.removeAll()
        freePoints.removeAll()
    }

    /// Tras mover un punto de un arco, el extremo opuesto podría quedar fuera
    /// del círculo: se re-proyecta. Si se movió el centro, se conserva el radio
    /// re-proyectando el extremo final (start manda, como al construir).
    private mutating func fixupArcs(touching moved: PointID) {
        for cid in curvesAttached(to: moved) {
            guard case .arc(let s, let e, let c, let ccw) = curves[cid]?.kind,
                  let cPos = positions[c], let sPos = positions[s], let ePos = positions[e]
            else { continue }
            let r = sPos.distance(to: cPos)
            guard r > 1e-12 else { continue }
            let fixedEnd = cPos + (ePos - cPos).normalized * r
            if fixedEnd.distance(to: ePos) > 1e-12 {
                // No fusionar aquí: el extremo del arco conserva su identidad.
                positions[e] = fixedEnd
                _ = ccw // sentido no cambia al re-proyectar
            }
        }
    }
}
