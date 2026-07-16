import Foundation

/// Resultado de un toque sobre el sketch, en orden de prioridad:
/// punto > curva > región > nada. Es lo que hace que "tocar un dibujo lo
/// seleccione" — la capacidad que el sistema viejo nunca tuvo.
public enum SketchHit: Sendable {
    case point(PointID, position: Vec2)
    case curve(CurveID, closest: Vec2)
    case region(SketchRegion)
    case none

    public var isNone: Bool {
        if case .none = self { return true }
        return false
    }
}

public struct HitTester: Sendable {
    public init() {}

    /// - Parameters:
    ///   - pointRadius: radio para agarrar un punto (mayor que curveRadius:
    ///     los puntos ganan cuando están cerca).
    ///   - curveRadius: radio para agarrar un trazo. Con dedo la UI pasa radios
    ///     generosos; con Pencil, finos.
    ///   - regions: pásalas cacheadas (RegionFinder es O(n²) en cruces).
    public func hitTest(at p: Vec2, in model: SketchModel,
                        pointRadius: Double, curveRadius: Double,
                        regions: [SketchRegion] = []) -> SketchHit {
        // 1. Puntos topológicos (extremos, centros, ctrl de spline, sueltos)
        var bestPoint: (PointID, Vec2, Double)?
        for (pid, pos) in model.positions {
            let d = pos.distance(to: p)
            if d <= pointRadius && d < (bestPoint?.2 ?? .infinity) {
                bestPoint = (pid, pos, d)
            }
        }
        if let (pid, pos, _) = bestPoint { return .point(pid, position: pos) }

        // 2. Curvas (distancia exacta al trazo)
        var bestCurve: (CurveID, Vec2, Double)?
        for curve in model.orderedCurves {
            guard let g = CurveGeometry.resolve(curve, in: model) else { continue }
            guard g.boundingBox.expanded(by: curveRadius).contains(p) else { continue }
            let c = g.closestPoint(to: p)
            if c.distance <= curveRadius && c.distance < (bestCurve?.2 ?? .infinity) {
                bestCurve = (curve.id, c.point, c.distance)
            }
        }
        if let (cid, q, _) = bestCurve { return .curve(cid, closest: q) }

        // 3. Regiones (la más pequeña que contenga el punto)
        if let region = RegionFinder.region(at: p, in: regions) {
            return .region(region)
        }

        return .none
    }

    /// Cadena conectada de curvas a partir de una (doble tap = seleccionar el
    /// perfil completo): expansión por extremos compartidos.
    public func connectedChain(from start: CurveID, in model: SketchModel) -> Set<CurveID> {
        guard let startCurve = model.curves[start] else { return [] }
        var chain: Set<CurveID> = [start]
        var frontier: [PointID] = startCurve.endpoints.map { [$0.0, $0.1] } ?? []
        var visitedPoints = Set<PointID>()

        while let point = frontier.popLast() {
            guard !visitedPoints.contains(point) else { continue }
            visitedPoints.insert(point)
            for cid in model.curvesAttached(to: point) where !chain.contains(cid) {
                // Solo conexión por EXTREMOS (compartir centro no encadena)
                guard let eps = model.curves[cid]?.endpoints,
                      eps.0 == point || eps.1 == point else { continue }
                chain.insert(cid)
                frontier.append(eps.0 == point ? eps.1 : eps.0)
            }
        }
        return chain
    }
}
