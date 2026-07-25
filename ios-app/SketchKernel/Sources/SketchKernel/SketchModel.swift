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

    // MARK: - Offset 2D (contorno paralelo)

    /// Desplaza una cadena conectada de LÍNEAS a distancia `distance`, creando
    /// un contorno paralelo. Signo positivo = hacia la izquierda del sentido de
    /// recorrido de la cadena; negativo = hacia la derecha.
    ///
    /// Es EXACTO, no una aproximación: cada recta desplazada es una recta
    /// paralela, y las esquinas se resuelven INTERSECTANDO las rectas
    /// desplazadas consecutivas (esquina en inglete). Así el contorno resultante
    /// mantiene la distancia real en todos sus tramos — que es justo lo que se
    /// necesita para paredes, holguras y contornos de mecanizado.
    ///
    /// v1 cubre cadenas de líneas (el caso dominante: perfiles poligonales).
    /// Con arcos o splines devuelve `nil` en vez de aproximar — el arco
    /// desplazado es concéntrico de radio r±d y entra en una versión siguiente.
    ///
    /// - Returns: los IDs de las curvas nuevas, o `nil` si la cadena no es
    ///   válida (curvas que no son líneas, no conectadas, o menos de una).
    @discardableResult
    public mutating func offsetLineChain(_ ids: [CurveID], distance: Double) -> [CurveID]? {
        guard abs(distance) > mergeTolerance, !ids.isEmpty else { return nil }
        guard let chain = orderedLineChain(ids) else { return nil }

        // Recta desplazada de cada tramo: se guarda como (punto, dirección).
        // La normal izquierda de una dirección (dx,dy) es (−dy,dx).
        var shifted: [(origin: Vec2, dir: Vec2)] = []
        shifted.reserveCapacity(chain.points.count)
        for i in 0..<(chain.points.count - 1) {
            let a = chain.points[i], b = chain.points[i + 1]
            let dir = (b - a).normalized
            let normal = dir.perpendicular          // izquierda
            shifted.append((a + normal * distance, dir))
        }
        guard !shifted.isEmpty else { return nil }

        // Vértices del contorno desplazado: los extremos son el desplazamiento
        // directo; los interiores, la intersección de las dos rectas vecinas.
        var corners: [Vec2] = []
        corners.reserveCapacity(shifted.count + 1)

        if chain.isClosed {
            // En un bucle, TODO vértice es interior: el primero se resuelve con
            // el último tramo.
            guard let first = intersectLines(shifted[shifted.count - 1], shifted[0]) else {
                return nil
            }
            corners.append(first)
        } else {
            corners.append(shifted[0].origin)
        }

        for i in 0..<(shifted.count - 1) {
            guard let x = intersectLines(shifted[i], shifted[i + 1]) else { return nil }
            corners.append(x)
        }

        if chain.isClosed {
            corners.append(corners[0])              // cerrar el bucle
        } else {
            let last = shifted[shifted.count - 1]
            let endA = chain.points[chain.points.count - 2]
            let endB = chain.points[chain.points.count - 1]
            corners.append(last.origin + (endB - endA))
        }

        var created: [CurveID] = []
        for i in 0..<(corners.count - 1) {
            let a = corners[i], b = corners[i + 1]
            guard a.distance(to: b) > mergeTolerance else { continue }
            created.append(addLine(from: a, to: b))
        }
        return created.isEmpty ? nil : created
    }

    /// Intersección de dos rectas infinitas dadas por (punto, dirección).
    /// `nil` si son paralelas — dos tramos colineales no forman esquina.
    private func intersectLines(_ p: (origin: Vec2, dir: Vec2),
                                _ q: (origin: Vec2, dir: Vec2)) -> Vec2? {
        let denom = p.dir.cross(q.dir)
        guard abs(denom) > 1e-12 else { return nil }
        let t = (q.origin - p.origin).cross(q.dir) / denom
        return p.origin + p.dir * t
    }

    /// Ordena las líneas dadas en una cadena conectada y devuelve sus vértices
    /// en orden de recorrido. `nil` si alguna no es línea o no forman UNA cadena.
    private func orderedLineChain(_ ids: [CurveID])
        -> (points: [Vec2], isClosed: Bool)? {
        // Adyacencia por PUNTO TOPOLÓGICO compartido — el invariante del kernel.
        var ends: [CurveID: (PointID, PointID)] = [:]
        var degree: [PointID: Int] = [:]
        for id in ids {
            guard case .line(let s, let e)? = curves[id]?.kind, s != e else { return nil }
            ends[id] = (s, e)
            degree[s, default: 0] += 1
            degree[e, default: 0] += 1
        }
        guard ends.count == ids.count else { return nil }
        // Una cadena simple: todo punto tiene grado 1 (extremos) o 2 (interior).
        guard degree.values.allSatisfy({ $0 <= 2 }) else { return nil }
        let endpoints = degree.filter { $0.value == 1 }.map { $0.key }
        let isClosed = endpoints.isEmpty
        guard isClosed || endpoints.count == 2 else { return nil }

        var remaining = Set(ids)
        var current: PointID
        if let start = endpoints.min(by: { $0.raw.uuidString < $1.raw.uuidString }) {
            current = start
        } else if let any = ends[ids[0]]?.0 {
            current = any
        } else {
            return nil
        }

        var points: [Vec2] = []
        guard let p0 = positions[current] else { return nil }
        points.append(p0)

        while let next = remaining.first(where: { id in
            guard let (s, e) = ends[id] else { return false }
            return s == current || e == current
        }) {
            guard let (s, e) = ends[next] else { return nil }
            let other = (s == current) ? e : s
            guard let pos = positions[other] else { return nil }
            points.append(pos)
            remaining.remove(next)
            current = other
        }
        // Todas las líneas deben haberse consumido: si sobra alguna, los `ids`
        // no formaban UNA sola cadena.
        guard remaining.isEmpty, points.count >= 2 else { return nil }

        // En un BUCLE el punto de partida tiene dos líneas candidatas, así que
        // el recorrido podría salir CW o CCW según el orden del Set. Como el
        // lado del offset se define respecto al sentido de recorrido, eso haría
        // que el contorno saliera hacia dentro o hacia fuera AL AZAR.
        // Se normaliza a CCW (área firmada positiva): así "izquierda" = "hacia
        // dentro" siempre, que además es la semántica que espera el usuario.
        if isClosed, signedArea(points) < 0 {
            points.reverse()
        }
        return (points, isClosed)
    }

    /// Área firmada (shoelace) del polígono; el último punto repetido no estorba.
    private func signedArea(_ pts: [Vec2]) -> Double {
        guard pts.count >= 3 else { return 0 }
        var acc = 0.0
        for i in 0..<pts.count {
            let a = pts[i], b = pts[(i + 1) % pts.count]
            acc += a.cross(b)
        }
        return acc / 2
    }

    // MARK: - Espejo 2D

    /// Refleja las curvas dadas sobre un eje y añade las copias al sketch.
    ///
    /// Exacto para TODOS los tipos: una recta refleja a recta, un círculo a
    /// círculo del mismo radio, un arco a arco del mismo radio (con el sentido
    /// INVERTIDO, porque una reflexión cambia la orientación del plano) y una
    /// spline a spline con sus puntos reflejados. Nada se discretiza.
    ///
    /// La topología se cose sola: las copias pasan por `addOrMergePoint`, así
    /// que los puntos que caen SOBRE el eje se funden con sus originales. Por
    /// eso reflejar media pieza sobre su borde produce un perfil cerrado único
    /// —extruible— y no dos mitades sueltas.
    ///
    /// - Parameters:
    ///   - ids: curvas a reflejar. Las que no existan se ignoran.
    ///   - axisPoint: un punto del eje de simetría.
    ///   - axisDirection: dirección del eje (no hace falta normalizarla).
    /// - Returns: los IDs de las curvas nuevas, en el orden de `ids`.
    @discardableResult
    public mutating func mirrorCurves(_ ids: [CurveID],
                                      axisPoint: Vec2,
                                      axisDirection: Vec2) -> [CurveID] {
        // OJO: comprobar la dirección CRUDA. `Vec2.normalized` devuelve (1,0)
        // para el vector cero, así que validar la normalizada dejaría pasar un
        // eje degenerado y reflejaría en silencio sobre el eje X.
        guard axisDirection.lengthSquared > 1e-24 else { return [] }
        let dir = axisDirection.normalized

        /// Reflexión de un punto sobre el eje: `p' = a + 2(v·d)d − v`, con
        /// `v = p − a`. Los puntos del eje quedan fijos (por eso se funden).
        func reflect(_ p: Vec2) -> Vec2 {
            let v = p - axisPoint
            return axisPoint + dir * (2 * v.dot(dir)) - v
        }

        /// ¿El punto queda FIJO por la reflexión? (es decir, cae sobre el eje)
        func isOnAxis(_ p: Vec2) -> Bool {
            p.distance(to: reflect(p)) <= mergeTolerance
        }

        var created: [CurveID] = []
        for id in ids {
            guard let curve = curves[id] else { continue }
            switch curve.kind {
            case .line(let s, let e):
                guard let sp = positions[s], let ep = positions[e] else { continue }
                // Un segmento contenido EN el eje se refleja sobre sí mismo:
                // duplicarlo pondría dos aristas encima y rompería la detección
                // de regiones (el grafo planar vería un tramo doble).
                guard !(isOnAxis(sp) && isOnAxis(ep)) else { continue }
                let a = addOrMergePoint(at: reflect(sp))
                let b = addOrMergePoint(at: reflect(ep))
                guard a != b else { continue }   // degenerado
                created.append(insert(SketchCurve(kind: .line(start: a, end: b),
                                                  isConstruction: curve.isConstruction)))

            case .circle(let c, let r):
                guard let cp = positions[c] else { continue }
                // Un círculo centrado en el eje ya es simétrico: se mapea a sí
                // mismo y su copia sería geometría duplicada.
                guard !isOnAxis(cp) else { continue }
                let nc = addOrMergePoint(at: reflect(cp))
                created.append(insert(SketchCurve(kind: .circle(center: nc, radius: r),
                                                  isConstruction: curve.isConstruction)))

            case .arc(let s, let e, let c, let ccw):
                guard let sp = positions[s], let ep = positions[e],
                      let cp = positions[c] else { continue }
                let a = addOrMergePoint(at: reflect(sp))
                let b = addOrMergePoint(at: reflect(ep))
                let nc = addOrMergePoint(at: reflect(cp))
                // La reflexión invierte la orientación del plano: un arco CCW
                // pasa a recorrerse CW. Sin esto el espejo sale por el lado malo.
                created.append(insert(SketchCurve(kind: .arc(start: a, end: b,
                                                             center: nc, ccw: !ccw),
                                                  isConstruction: curve.isConstruction)))

            case .spline(let pts, let mode):
                let mirrored = pts.compactMap { positions[$0].map(reflect) }
                guard mirrored.count == pts.count, mirrored.count >= 2 else { continue }
                let newIDs = mirrored.map { addOrMergePoint(at: $0) }
                created.append(insert(SketchCurve(kind: .spline(points: newIDs, mode: mode),
                                                  isConstruction: curve.isConstruction)))
            }
        }
        return created
    }

    /// Espejo de TODAS las curvas no-construcción del sketch. Atajo del caso
    /// dominante: dibujas media pieza y la completas de un toque.
    @discardableResult
    public mutating func mirrorAll(axisPoint: Vec2, axisDirection: Vec2) -> [CurveID] {
        let ids = curveOrder.filter { curves[$0]?.isConstruction == false }
        return mirrorCurves(ids, axisPoint: axisPoint, axisDirection: axisDirection)
    }

    // MARK: - Redondeo de esquina (fillet 2D)

    /// Redondea la esquina donde se tocan DOS líneas, insertando un arco
    /// TANGENTE a ambas y recortándolas hasta los puntos de tangencia.
    ///
    /// Es la operación más usada del dibujo mecánico y no existía. Cobra sentido
    /// pleno con los perfiles analíticos: el arco que se inserta aquí sobrevive
    /// hasta el B-rep como una cara cilíndrica REAL, no como los ~25 segmentos
    /// en que se habría discretizado antes.
    ///
    /// Geometría (bisectriz):
    ///   · `t = r / tan(α/2)` es la distancia desde la esquina a cada punto de
    ///     tangencia, con α el ángulo interior entre las dos líneas.
    ///   · el centro cae sobre la bisectriz a `r / sin(α/2)` de la esquina.
    ///
    /// Devuelve el `CurveID` del arco nuevo, o `nil` si no se puede redondear:
    /// esquina que no une exactamente dos líneas, líneas casi colineales
    /// (α≈0 o α≈π, donde el radio se va a infinito) o radio tan grande que el
    /// redondeo se comería alguno de los dos segmentos.
    @discardableResult
    public mutating func filletCorner(at corner: PointID, radius: Double) -> CurveID? {
        guard radius > mergeTolerance, let p = positions[corner] else { return nil }

        // Exactamente dos líneas compartiendo la esquina.
        let attached = curvesAttached(to: corner)
        guard attached.count == 2 else { return nil }
        var farEnds: [(curve: CurveID, far: PointID, pos: Vec2)] = []
        for cid in attached {
            guard case .line(let s, let e)? = curves[cid]?.kind else { return nil }
            let far = (s == corner) ? e : s
            guard far != corner, let fp = positions[far] else { return nil }
            farEnds.append((cid, far, fp))
        }

        let d1 = (farEnds[0].pos - p).normalized
        let d2 = (farEnds[1].pos - p).normalized
        let cosA = max(-1, min(1, d1.dot(d2)))
        let alpha = acos(cosA)
        // Colineales (α≈0 o α≈π): no hay esquina que redondear.
        guard alpha > 1e-6, alpha < .pi - 1e-6 else { return nil }

        let halfA = alpha / 2
        let tanHalf = tan(halfA)
        let sinHalf = sin(halfA)
        guard tanHalf > 1e-12, sinHalf > 1e-12 else { return nil }

        let t = radius / tanHalf
        // El redondeo no puede comerse ninguno de los dos segmentos.
        let len1 = p.distance(to: farEnds[0].pos)
        let len2 = p.distance(to: farEnds[1].pos)
        guard t > mergeTolerance, t < len1 - mergeTolerance, t < len2 - mergeTolerance else {
            return nil
        }

        let tangent1 = p + d1 * t
        let tangent2 = p + d2 * t
        let bisector = (d1 + d2).normalized
        let center = p + bisector * (radius / sinHalf)

        // Re-cablear cada línea para que termine en SU punto de tangencia. Se
        // crean puntos nuevos: la esquina compartida deja de existir como tal.
        let t1ID = addOrMergePoint(at: tangent1)
        let t2ID = addOrMergePoint(at: tangent2)
        replaceEndpoint(of: farEnds[0].curve, from: corner, to: t1ID)
        replaceEndpoint(of: farEnds[1].curve, from: corner, to: t2ID)

        // La esquina queda huérfana salvo que sea un punto suelto explícito.
        if !freePoints.contains(corner), curvesAttached(to: corner).isEmpty {
            positions[corner] = nil
        }

        // Sentido del barrido: el arco va de T1 a T2 por el lado CORTO (su
        // barrido es π−α < π), así que lo decide el signo del producto cruz.
        let ccw = (tangent1 - center).cross(tangent2 - center) > 0
        let arc = SketchCurve(kind: .arc(start: t1ID, end: t2ID,
                                         center: addOrMergePoint(at: center), ccw: ccw))
        return insert(arc)
    }

    /// Sustituye un extremo de una línea conservando su identidad de curva.
    private mutating func replaceEndpoint(of id: CurveID, from old: PointID, to new: PointID) {
        guard case .line(let s, let e)? = curves[id]?.kind else { return }
        curves[id]?.kind = .line(start: s == old ? new : s,
                                 end: e == old ? new : e)
    }

    // MARK: - Trim (recorte por intersecciones)

    /// Recorta la curva `id` en el tramo que contiene el punto `p`: calcula
    /// TODAS las intersecciones con las demás curvas, parametriza los cortes
    /// sobre el target y elimina el tramo entre los dos cortes que rodean a `p`.
    /// Mecánica de `CommandGeoTrim` de FreeCAD, pero geométrica (sin solver).
    ///
    /// - Línea → 0/1/2 líneas restantes (los extremos NO tocados conservan su
    ///   PointID; los cortes se fusionan por topología con `addOrMergePoint`).
    /// - Círculo → arco complementario (requiere ≥2 cortes; con <2 no-op → false).
    /// - Arco → arco(s) recortado(s).
    /// - Spline → no soportado en v1 (return false).
    /// - Sin intersecciones → borra la curva entera (trim de curva suelta =
    ///   borrar, como Shapr3D) y devuelve true.
    @discardableResult
    public mutating func trim(_ id: CurveID, at p: Vec2) -> Bool {
        guard let curve = curves[id],
              let g = CurveGeometry.resolve(curve, in: self) else { return false }

        // Spline: no soportada en v1.
        if case .spline = curve.kind { return false }

        // 1. Parámetros t de los cortes con las demás curvas.
        var cutTs: [Double] = []
        for other in orderedCurves where other.id != id {
            guard let og = CurveGeometry.resolve(other, in: self) else { continue }
            for x in Intersections.between(g, og) {
                let t = g.closestPoint(to: x).t
                cutTs.append(t)
            }
        }

        switch curve.kind {
        case .line(let sID, let eID):
            return trimLine(id, startID: sID, endID: eID, g: g, cuts: cutTs, at: p)
        case .circle:
            return trimCircle(id, g: g, cuts: cutTs, at: p)
        case .arc(let sID, let eID, let cID, let ccw):
            return trimArc(id, startID: sID, endID: eID, centerID: cID, ccw: ccw,
                           g: g, cuts: cutTs, at: p)
        case .spline:
            return false
        }
    }

    /// Cortes válidos ordenados en (0,1) sin duplicados (por tolerancia en t).
    private func normalizedInteriorCuts(_ cuts: [Double], epsilon: Double = 1e-6) -> [Double] {
        var uniq: [Double] = []
        for t in cuts.sorted() where t > epsilon && t < 1 - epsilon {
            if uniq.last.map({ abs($0 - t) > epsilon }) ?? true { uniq.append(t) }
        }
        return uniq
    }

    /// Línea: los cortes interiores + 0 y 1 forman las fronteras; se elimina el
    /// tramo que contiene la proyección de `p`; los demás sobreviven como líneas.
    private mutating func trimLine(_ id: CurveID, startID: PointID, endID: PointID,
                                   g: CurveGeometry, cuts: [Double], at p: Vec2) -> Bool {
        let interior = normalizedInteriorCuts(cuts)
        // Sin cortes → borrar la curva suelta entera.
        guard !interior.isEmpty else { removeCurve(id); return true }

        let bounds = [0.0] + interior + [1.0]
        let tp = g.closestPoint(to: p).t
        // Tramo [bounds[k], bounds[k+1]] que contiene tp.
        var kill = 0
        for k in 0..<(bounds.count - 1) where tp >= bounds[k] && tp <= bounds[k + 1] {
            kill = k; break
        }
        // Reconstruir los tramos SALVO el eliminado, preservando PointIDs de
        // los extremos originales (t=0 → startID; t=1 → endID) que sobrevivan.
        removeCurve(id)
        for k in 0..<(bounds.count - 1) where k != kill {
            let t0 = bounds[k], t1 = bounds[k + 1]
            let a = t0 <= 1e-9 ? startID : addOrMergePoint(at: g.evaluate(t0))
            let b = t1 >= 1 - 1e-9 ? endID : addOrMergePoint(at: g.evaluate(t1))
            // Los extremos originales pudieron quedar huérfanos al remover la
            // curva; re-crearlos si hace falta manteniendo su identidad.
            ensurePoint(a, at: g.evaluate(t0))
            ensurePoint(b, at: g.evaluate(t1))
            _ = addLine(from: a, to: b)
        }
        return true
    }

    /// Círculo → arco: con ≥2 cortes, quita el sector que contiene `p` dejando
    /// el arco complementario (de un corte al otro, por el lado sin `p`).
    private mutating func trimCircle(_ id: CurveID, g: CurveGeometry,
                                     cuts: [Double], at p: Vec2) -> Bool {
        // Un círculo puede tener cortes en t≈0/1 (mismo punto): normalizar en
        // el aro [0,1) sin la restricción interior, tratando ≈1 como ≈0 (wrap).
        func wrap(_ t: Double) -> Double {
            var v = t.truncatingRemainder(dividingBy: 1)
            if v < 0 { v += 1 }
            if v > 1 - 1e-6 { v = 0 }
            return v
        }
        var ring: [Double] = []
        for t in cuts.map(wrap).sorted() {
            if ring.last.map({ abs($0 - t) > 1e-6 }) ?? true { ring.append(t) }
        }
        guard ring.count >= 2 else { return false } // <2 cortes: no-op

        // Tramos del aro entre cortes consecutivos (envolviendo). Se elimina el
        // que contiene tp; el resto se une en un arco por sus extremos.
        let tpN = wrap(g.closestPoint(to: p).t)
        // Encontrar el par de cortes (a,b) tal que tp caiga en (a,b) del aro.
        var killLo = ring[ring.count - 1], killHi = ring[0]
        var found = false
        for k in 0..<(ring.count - 1) where tpN >= ring[k] && tpN <= ring[k + 1] {
            killLo = ring[k]; killHi = ring[k + 1]; found = true; break
        }
        if !found { killLo = ring[ring.count - 1]; killHi = ring[0] } // tramo que envuelve 1→0
        // El arco que SOBREVIVE va de killHi (avanzando CCW) a killLo.
        guard case .circle(let center, let radius) = g.shape else { return false }
        let startAng = 2 * .pi * killHi
        let endAng = 2 * .pi * killLo
        let sPos = center + Vec2(cos(startAng), sin(startAng)) * radius
        let ePos = center + Vec2(cos(endAng), sin(endAng)) * radius
        removeCurve(id)
        _ = addArc(center: center, start: sPos, end: ePos, ccw: true)
        return true
    }

    /// Arco → arco(s): igual que la línea pero sobre el barrido; los extremos
    /// (t=0 start, t=1 end) conservan su PointID si sobreviven.
    private mutating func trimArc(_ id: CurveID, startID: PointID, endID: PointID,
                                  centerID: PointID, ccw: Bool,
                                  g: CurveGeometry, cuts: [Double], at p: Vec2) -> Bool {
        let interior = normalizedInteriorCuts(cuts)
        guard !interior.isEmpty else { removeCurve(id); return true }

        guard let centerPos = positions[centerID],
              case .arc = g.shape else { return false }
        let bounds = [0.0] + interior + [1.0]
        let tp = g.closestPoint(to: p).t
        var kill = 0
        for k in 0..<(bounds.count - 1) where tp >= bounds[k] && tp <= bounds[k + 1] {
            kill = k; break
        }
        removeCurve(id)
        for k in 0..<(bounds.count - 1) where k != kill {
            let t0 = bounds[k], t1 = bounds[k + 1]
            let sPos = g.evaluate(t0), ePos = g.evaluate(t1)
            // El sub-arco conserva centro, radio y sentido; ccw se mantiene
            // porque evaluate ya respeta el sentido del barrido original.
            let a = t0 <= 1e-9 ? startID : addOrMergePoint(at: sPos)
            let b = t1 >= 1 - 1e-9 ? endID : addOrMergePoint(at: ePos)
            ensurePoint(a, at: sPos)
            ensurePoint(b, at: ePos)
            ensurePoint(centerID, at: centerPos)
            _ = insert(SketchCurve(kind: .arc(start: a, end: b, center: centerID, ccw: ccw)))
        }
        return true
    }

    /// Garantiza que un PointID exista en `positions` en la posición dada (los
    /// extremos originales pudieron quedar huérfanos al remover la curva vieja).
    private mutating func ensurePoint(_ id: PointID, at p: Vec2) {
        if positions[id] == nil { positions[id] = p }
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
