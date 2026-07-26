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
        //
        // `model.positions` es un DICCIONARIO: su orden de iteración no está
        // garantizado. Con `<` estricto, entre dos puntos EQUIDISTANTES ganaba
        // el que saliera primero — o sea, uno al azar entre ejecuciones. Tocar
        // justo en medio de dos esquinas simétricas seleccionaba una u otra sin
        // criterio, y los sketches simétricos son comunes (más aún desde que
        // existe el espejo). El desempate por posición lo hace reproducible.
        var bestPoint: (PointID, Vec2, Double)?
        for (pid, pos) in model.positions {
            let d = pos.distance(to: p)
            guard d <= pointRadius else { continue }
            guard let current = bestPoint else {
                bestPoint = (pid, pos, d)
                continue
            }
            if d < current.2 - 1e-12 {
                bestPoint = (pid, pos, d)
            } else if abs(d - current.2) <= 1e-12,
                      (pos.x, pos.y) < (current.1.x, current.1.y) {
                bestPoint = (pid, pos, d)   // empate: gana el menor en (x,y)
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
        // La cadena NO cruza la frontera construcción/real. Un eje de
        // construcción suele tocar el perfil, así que sin esto el doble tap
        // sobre un contorno se llevaba los helpers a la selección — y después
        // Espejo u Offset actuaban sobre ellos.
        let wantsConstruction = startCurve.isConstruction
        var chain: Set<CurveID> = [start]
        var frontier: [PointID] = startCurve.endpoints.map { [$0.0, $0.1] } ?? []
        var visitedPoints = Set<PointID>()

        while let point = frontier.popLast() {
            guard !visitedPoints.contains(point) else { continue }
            visitedPoints.insert(point)
            for cid in model.curvesAttached(to: point) where !chain.contains(cid) {
                guard let curve = model.curves[cid],
                      curve.isConstruction == wantsConstruction else { continue }
                // Solo conexión por EXTREMOS (compartir centro no encadena)
                guard let eps = curve.endpoints,
                      eps.0 == point || eps.1 == point else { continue }
                chain.insert(cid)
                frontier.append(eps.0 == point ? eps.1 : eps.0)
            }
        }
        return chain
    }
}
