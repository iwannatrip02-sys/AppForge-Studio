import Foundation

/// Tipo de enganche, en orden de PRIORIDAD (menor = gana). El orden replica
/// Shapr3D: puntos duros primero, luego cruces de guías, luego sobre-curva,
/// guías solas, y la rejilla al final.
public enum SnapKind: Int, Comparable, Sendable {
    case endpoint = 0        // extremo/punto topológico existente
    case intersection = 1    // cruce real de dos curvas
    case midpoint = 2        // punto medio de línea/arco/spline
    case center = 3          // centro de círculo/arco
    case quadrant = 4        // N/E/S/O de círculos
    case guideIntersection = 5 // cruce de dos guías de inferencia
    case onCurve = 6         // el punto más cercano sobre una curva
    case guide = 7           // sobre una guía (H/V, alineación, extensión)
    case grid = 8            // rejilla
    case none = 9            // sin snap: posición libre

    public static func < (a: SnapKind, b: SnapKind) -> Bool { a.rawValue < b.rawValue }
}

/// Guía de inferencia visible (línea punteada) — la UI las dibuja tal cual.
public struct InferenceGuide: Equatable, Sendable {
    public enum Kind: Equatable, Sendable {
        case horizontal      // horizontal desde el punto de referencia
        case vertical        // vertical desde el punto de referencia
        case alignmentH      // alineación horizontal con un punto existente
        case alignmentV      // alineación vertical con un punto existente
        case lineExtension   // prolongación de una línea existente
    }
    public let kind: Kind
    /// Punto por el que pasa la guía (origen visual de la punteada).
    public let through: Vec2
    /// Dirección unitaria de la guía.
    public let direction: Vec2

    public init(kind: Kind, through: Vec2, direction: Vec2) {
        self.kind = kind
        self.through = through
        self.direction = direction
    }

    /// Proyección de un punto sobre la guía (recta infinita).
    public func project(_ p: Vec2) -> Vec2 {
        through + direction * (p - through).dot(direction)
    }

    /// Intersección con otra guía (nil si casi paralelas).
    public func intersection(with other: InferenceGuide) -> Vec2? {
        let denom = direction.cross(other.direction)
        guard abs(denom) > 1e-9 else { return nil }
        let t = (other.through - through).cross(other.direction) / denom
        return through + direction * t
    }
}

/// Resultado del snap: dónde quedó el punto, por qué, y qué mostrar.
public struct SnapResult: Sendable {
    public var position: Vec2
    public var kind: SnapKind
    /// Punto topológico enganchado (para FUSIONAR al confirmar: dibujar desde
    /// un endpoint existente comparte ese punto — topología conectada).
    public var pointID: PointID?
    /// Curva enganchada (onCurve / midpoint / center / quadrant).
    public var curveID: CurveID?
    /// Guías activas a dibujar (0, 1 o 2).
    public var guides: [InferenceGuide]

    public init(position: Vec2, kind: SnapKind,
                pointID: PointID? = nil, curveID: CurveID? = nil,
                guides: [InferenceGuide] = []) {
        self.position = position
        self.kind = kind
        self.pointID = pointID
        self.curveID = curveID
        self.guides = guides
    }
}

/// Contexto de una consulta de snap. El RADIO viene de la UI ya convertido a
/// unidades de sketch (adaptativo al zoom; menor con Pencil que con dedo).
public struct SnapContext: Sendable {
    public var cursor: Vec2
    public var radius: Double
    /// Punto anterior del trazo en curso (activa guías H/V y entrada de ángulo).
    public var referencePoint: Vec2?
    /// Puntos a IGNORAR (p. ej. el que se está arrastrando).
    public var excludedPoints: Set<PointID>
    /// Curvas a ignorar (la que se está editando).
    public var excludedCurves: Set<CurveID>
    /// Paso de rejilla (nil = sin snap de rejilla).
    public var gridSpacing: Double?

    public init(cursor: Vec2, radius: Double,
                referencePoint: Vec2? = nil,
                excludedPoints: Set<PointID> = [],
                excludedCurves: Set<CurveID> = [],
                gridSpacing: Double? = nil) {
        self.cursor = cursor
        self.radius = radius
        self.referencePoint = referencePoint
        self.excludedPoints = excludedPoints
        self.excludedCurves = excludedCurves
        self.gridSpacing = gridSpacing
    }
}

/// Motor de snap: candidatos duros (puntos/cruces/curvas) + guías de
/// inferencia, resueltos por (prioridad, distancia). Sin estado: cada frame
/// de drag consulta con el cursor actual.
public struct SnapEngine: Sendable {
    /// Máximo de puntos de alineación considerados (rendimiento en sketches grandes).
    public var maxAlignmentSources: Int = 64

    public init() {}

    public func snap(_ ctx: SnapContext, in model: SketchModel) -> SnapResult {
        let r = ctx.radius
        var best: SnapResult?

        func consider(_ candidate: SnapResult, distance: Double) {
            guard distance <= r else { return }
            if let b = best {
                let bd = b.position.distance(to: ctx.cursor)
                if candidate.kind < b.kind || (candidate.kind == b.kind && distance < bd) {
                    best = candidate
                }
            } else {
                best = candidate
            }
        }

        let geometries = model.orderedCurves
            .filter { !ctx.excludedCurves.contains($0.id) }
            .compactMap { CurveGeometry.resolve($0, in: model) }

        // 1. Puntos topológicos existentes (endpoints, centros, ctrl de spline)
        for (pid, pos) in model.positions where !ctx.excludedPoints.contains(pid) {
            consider(SnapResult(position: pos, kind: .endpoint, pointID: pid),
                     distance: pos.distance(to: ctx.cursor))
        }

        // 2. Intersecciones reales curva×curva cerca del cursor
        for i in 0..<geometries.count {
            let bi = geometries[i].boundingBox.expanded(by: r)
            guard bi.contains(ctx.cursor) else { continue }
            for j in (i + 1)..<geometries.count {
                let bj = geometries[j].boundingBox.expanded(by: r)
                guard bj.contains(ctx.cursor) else { continue }
                for x in Intersections.between(geometries[i], geometries[j]) {
                    consider(SnapResult(position: x, kind: .intersection),
                             distance: x.distance(to: ctx.cursor))
                }
            }
        }

        // 3. Puntos notables de curvas: medio, centro, cuadrantes
        for g in geometries {
            if let m = g.midpoint {
                consider(SnapResult(position: m, kind: .midpoint, curveID: g.curveID),
                         distance: m.distance(to: ctx.cursor))
            }
            if let c = g.center {
                consider(SnapResult(position: c, kind: .center, curveID: g.curveID),
                         distance: c.distance(to: ctx.cursor))
            }
            for q in g.quadrants {
                consider(SnapResult(position: q, kind: .quadrant, curveID: g.curveID),
                         distance: q.distance(to: ctx.cursor))
            }
        }

        // Si ya hay un snap "duro" (mejor que guías), listo.
        if let b = best, b.kind < .guideIntersection { return b }

        // 4. Guías de inferencia
        let guides = activeGuides(ctx, in: model, geometries: geometries)

        // 4a. Cruce de dos guías (p. ej. horizontal-del-anterior × alineación-vertical)
        if guides.count >= 2 {
            var bestCross: (Vec2, InferenceGuide, InferenceGuide, Double)?
            for i in 0..<guides.count {
                for j in (i + 1)..<guides.count {
                    if let x = guides[i].intersection(with: guides[j]) {
                        let d = x.distance(to: ctx.cursor)
                        if d <= r && d < (bestCross?.3 ?? .infinity) {
                            bestCross = (x, guides[i], guides[j], d)
                        }
                    }
                }
            }
            if let (x, g1, g2, d) = bestCross {
                consider(SnapResult(position: x, kind: .guideIntersection,
                                    guides: [g1, g2]), distance: d)
            }
        }

        if let b = best, b.kind < .onCurve { return b }

        // 5. Sobre-curva (punto más cercano de la curva más cercana)
        var bestOn: (CurveGeometry.Closest, CurveID)?
        for g in geometries {
            let c = g.closestPoint(to: ctx.cursor)
            if c.distance <= r && c.distance < (bestOn?.0.distance ?? .infinity) {
                bestOn = (c, g.curveID)
            }
        }
        if let (c, cid) = bestOn {
            consider(SnapResult(position: c.point, kind: .onCurve, curveID: cid),
                     distance: c.distance)
        }

        if let b = best, b.kind < .guide { return b }

        // 6. Una sola guía: proyectar el cursor sobre ella
        var bestGuide: (Vec2, InferenceGuide, Double)?
        for g in guides {
            let q = g.project(ctx.cursor)
            let d = q.distance(to: ctx.cursor)
            if d <= r && d < (bestGuide?.2 ?? .infinity) { bestGuide = (q, g, d) }
        }
        if let (q, g, d) = bestGuide {
            consider(SnapResult(position: q, kind: .guide, guides: [g]), distance: d)
        }

        if let b = best { return b }

        // 7. Rejilla
        if let spacing = ctx.gridSpacing, spacing > 1e-12 {
            let gp = Vec2((ctx.cursor.x / spacing).rounded() * spacing,
                          (ctx.cursor.y / spacing).rounded() * spacing)
            if gp.distance(to: ctx.cursor) <= r {
                return SnapResult(position: gp, kind: .grid)
            }
        }

        return SnapResult(position: ctx.cursor, kind: .none)
    }

    /// Guías activas para el cursor actual: H/V desde el punto de referencia,
    /// alineación H/V con puntos existentes, prolongación de líneas.
    func activeGuides(_ ctx: SnapContext, in model: SketchModel,
                      geometries: [CurveGeometry]) -> [InferenceGuide] {
        var guides: [InferenceGuide] = []
        let r = ctx.radius

        // H/V desde el punto anterior del trazo
        if let ref = ctx.referencePoint {
            if abs(ctx.cursor.y - ref.y) <= r {
                guides.append(InferenceGuide(kind: .horizontal, through: ref,
                                             direction: Vec2(1, 0)))
            }
            if abs(ctx.cursor.x - ref.x) <= r {
                guides.append(InferenceGuide(kind: .vertical, through: ref,
                                             direction: Vec2(0, 1)))
            }
        }

        // Alineación con puntos existentes (el punto NO está bajo el cursor,
        // pero comparte x o y — la punteada clásica de Shapr3D)
        var sources = 0
        for (pid, pos) in model.positions where !ctx.excludedPoints.contains(pid) {
            if sources >= maxAlignmentSources { break }
            // Ignorar puntos demasiado cerca del cursor (ya son snap endpoint)
            guard pos.distance(to: ctx.cursor) > r * 2 else { continue }
            if abs(ctx.cursor.x - pos.x) <= r {
                guides.append(InferenceGuide(kind: .alignmentV, through: pos,
                                             direction: Vec2(0, 1)))
                sources += 1
            } else if abs(ctx.cursor.y - pos.y) <= r {
                guides.append(InferenceGuide(kind: .alignmentH, through: pos,
                                             direction: Vec2(1, 0)))
                sources += 1
            }
        }

        // Prolongación de líneas existentes (cursor más allá del extremo)
        for g in geometries {
            guard case .line(let a, let b) = g.shape else { continue }
            let dir = (b - a).normalized
            let guide = InferenceGuide(kind: .lineExtension, through: a, direction: dir)
            let q = guide.project(ctx.cursor)
            guard q.distance(to: ctx.cursor) <= r else { continue }
            // Solo cuenta como "extensión" si cae FUERA del segmento
            let t = (q - a).dot(dir)
            let len = (b - a).length
            if t < -1e-9 || t > len + 1e-9 {
                guides.append(guide)
            }
        }

        return guides
    }
}
