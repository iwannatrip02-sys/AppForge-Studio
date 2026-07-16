import Foundation

/// Intersecciones curva-curva. Exactas para línea/círculo/arco; las splines
/// participan vía su polilínea de muestreo. Alimentan el snap (kind
/// .intersection) y el particionado del grafo de regiones.
public enum Intersections {

    /// Intersección de segmentos [a1,a2] × [b1,b2] (incluye extremos).
    public static func segmentSegment(_ a1: Vec2, _ a2: Vec2,
                                      _ b1: Vec2, _ b2: Vec2,
                                      tolerance: Double = 1e-9) -> Vec2? {
        let r = a2 - a1
        let s = b2 - b1
        let denom = r.cross(s)
        let qp = b1 - a1
        if abs(denom) < tolerance {
            return nil // paralelos o colineales: sin punto único
        }
        let t = qp.cross(s) / denom
        let u = qp.cross(r) / denom
        let e = tolerance
        guard t >= -e, t <= 1 + e, u >= -e, u <= 1 + e else { return nil }
        return a1 + r * min(1, max(0, t))
    }

    /// Segmento × círculo completo. 0-2 puntos.
    public static func segmentCircle(_ a: Vec2, _ b: Vec2,
                                     center: Vec2, radius: Double,
                                     tolerance: Double = 1e-9) -> [Vec2] {
        let d = b - a
        let f = a - center
        let A = d.lengthSquared
        guard A > tolerance * tolerance else { return [] }
        let B = 2 * f.dot(d)
        let C = f.lengthSquared - radius * radius
        let disc = B * B - 4 * A * C
        if disc < 0 { return [] }
        let sq = disc.squareRoot()
        var result: [Vec2] = []
        for t in [(-B - sq) / (2 * A), (-B + sq) / (2 * A)] {
            if t >= -tolerance, t <= 1 + tolerance {
                result.append(a + d * min(1, max(0, t)))
            }
        }
        // disc≈0 → raíces duplicadas (tangencia): deduplicar
        if result.count == 2, result[0].distance(to: result[1]) < tolerance * 10 {
            result.removeLast()
        }
        return result
    }

    /// Círculo × círculo. 0-2 puntos.
    public static func circleCircle(_ c1: Vec2, _ r1: Double,
                                    _ c2: Vec2, _ r2: Double,
                                    tolerance: Double = 1e-9) -> [Vec2] {
        let d = c1.distance(to: c2)
        if d < tolerance { return [] }               // concéntricos
        if d > r1 + r2 + tolerance { return [] }     // separados
        if d < abs(r1 - r2) - tolerance { return [] } // uno dentro del otro
        let a = (r1 * r1 - r2 * r2 + d * d) / (2 * d)
        let h2 = r1 * r1 - a * a
        let h = h2 > 0 ? h2.squareRoot() : 0
        let mid = c1 + (c2 - c1) * (a / d)
        let perp = (c2 - c1).normalized.perpendicular
        if h < tolerance { return [mid] }            // tangencia
        return [mid + perp * h, mid - perp * h]
    }

    /// Todas las intersecciones entre dos geometrías resueltas.
    /// Línea/círculo exactos entre sí; arco = círculo filtrado por barrido;
    /// spline = su polilínea.
    public static func between(_ g1: CurveGeometry, _ g2: CurveGeometry,
                               tolerance: Double = 1e-9) -> [Vec2] {
        switch (g1.shape, g2.shape) {
        case (.line(let a, let b), .line(let c, let d)):
            return segmentSegment(a, b, c, d, tolerance: tolerance).map { [$0] } ?? []

        case (.line(let a, let b), .circle(let c, let r)):
            return segmentCircle(a, b, center: c, radius: r, tolerance: tolerance)
        case (.circle(let c, let r), .line(let a, let b)):
            return segmentCircle(a, b, center: c, radius: r, tolerance: tolerance)

        case (.circle(let c1, let r1), .circle(let c2, let r2)):
            return circleCircle(c1, r1, c2, r2, tolerance: tolerance)

        case (.line(let a, let b), .arc(let c, let r, _, _, _)):
            return segmentCircle(a, b, center: c, radius: r, tolerance: tolerance)
                .filter { onArc($0, g2) }
        case (.arc(let c, let r, _, _, _), .line(let a, let b)):
            return segmentCircle(a, b, center: c, radius: r, tolerance: tolerance)
                .filter { onArc($0, g1) }

        case (.arc(let c1, let r1, _, _, _), .circle(let c2, let r2)):
            return circleCircle(c1, r1, c2, r2, tolerance: tolerance).filter { onArc($0, g1) }
        case (.circle(let c1, let r1), .arc(let c2, let r2, _, _, _)):
            return circleCircle(c1, r1, c2, r2, tolerance: tolerance).filter { onArc($0, g2) }

        case (.arc(let c1, let r1, _, _, _), .arc(let c2, let r2, _, _, _)):
            return circleCircle(c1, r1, c2, r2, tolerance: tolerance)
                .filter { onArc($0, g1) && onArc($0, g2) }

        // Splines: polilínea × cualquier cosa (vía discretización de ambas)
        default:
            return polylineIntersections(g1, g2, tolerance: tolerance)
        }
    }

    /// ¿El punto (ya sobre el círculo del arco) cae dentro del barrido?
    static func onArc(_ p: Vec2, _ g: CurveGeometry) -> Bool {
        guard case .arc = g.shape else { return true }
        let c = g.closestPoint(to: p)
        return c.distance < 1e-6
    }

    static func polylineIntersections(_ g1: CurveGeometry, _ g2: CurveGeometry,
                                      tolerance: Double) -> [Vec2] {
        let p1 = g1.discretize(maxDeviation: 5e-4)
        let p2 = g2.discretize(maxDeviation: 5e-4)
        var result: [Vec2] = []
        guard p1.count >= 2, p2.count >= 2 else { return result }
        for i in 0..<(p1.count - 1) {
            for j in 0..<(p2.count - 1) {
                if let x = segmentSegment(p1[i], p1[i + 1], p2[j], p2[j + 1],
                                          tolerance: tolerance) {
                    // Deduplicar contra vecinos (los extremos de tramos se repiten)
                    if !result.contains(where: { $0.distance(to: x) < 1e-6 }) {
                        result.append(x)
                    }
                }
            }
        }
        return result
    }

    /// Intersecciones de TODAS las parejas de curvas del modelo.
    public static func all(in model: SketchModel, tolerance: Double = 1e-9) -> [Vec2] {
        let geos = model.orderedCurves.compactMap { CurveGeometry.resolve($0, in: model) }
        var result: [Vec2] = []
        for i in 0..<geos.count {
            for j in (i + 1)..<geos.count {
                for x in between(geos[i], geos[j], tolerance: tolerance) {
                    if !result.contains(where: { $0.distance(to: x) < 1e-6 }) {
                        result.append(x)
                    }
                }
            }
        }
        return result
    }
}
