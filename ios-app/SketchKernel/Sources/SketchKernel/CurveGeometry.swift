import Foundation

/// Geometría evaluable de una curva: muestreo, punto más cercano, puntos
/// notables (snap) y discretización (regiones/render). Separada del modelo:
/// se construye resolviendo los PointID contra las posiciones actuales.
public struct CurveGeometry: Sendable {
    public enum Shape: Sendable {
        case line(a: Vec2, b: Vec2)
        /// startAngle→endAngle barriendo en sentido `ccw`. sweep > 0 siempre.
        case arc(center: Vec2, radius: Double, startAngle: Double, sweep: Double, ccw: Bool)
        case circle(center: Vec2, radius: Double)
        /// Polilínea de muestreo densa de la spline (la fuente de verdad para
        /// distancia/regiones; los puntos de control viven en el modelo).
        case sampledSpline(samples: [Vec2])
    }

    public let curveID: CurveID
    public let shape: Shape

    public init(curveID: CurveID, shape: Shape) {
        self.curveID = curveID
        self.shape = shape
    }

    /// Resuelve la geometría de una curva del modelo. nil si faltan puntos.
    public static func resolve(_ curve: SketchCurve, in model: SketchModel,
                               splineSamplesPerSegment: Int = 16) -> CurveGeometry? {
        switch curve.kind {
        case .line(let s, let e):
            guard let a = model.position(of: s), let b = model.position(of: e) else { return nil }
            return CurveGeometry(curveID: curve.id, shape: .line(a: a, b: b))

        case .arc(let s, let e, let c, let ccw):
            guard let sp = model.position(of: s), let ep = model.position(of: e),
                  let cp = model.position(of: c) else { return nil }
            let r = sp.distance(to: cp)
            guard r > 1e-12 else { return nil }
            let a0 = (sp - cp).angle
            let a1 = (ep - cp).angle
            var sweep = ccw ? (a1 - a0) : (a0 - a1)
            while sweep < 0 { sweep += 2 * .pi }
            while sweep > 2 * .pi { sweep -= 2 * .pi }
            if sweep < 1e-12 { sweep = 2 * .pi } // extremos coincidentes = vuelta completa
            return CurveGeometry(curveID: curve.id,
                                 shape: .arc(center: cp, radius: r, startAngle: a0, sweep: sweep, ccw: ccw))

        case .circle(let c, let r):
            guard let cp = model.position(of: c), r > 1e-12 else { return nil }
            return CurveGeometry(curveID: curve.id, shape: .circle(center: cp, radius: r))

        case .spline(let ids, let mode):
            let pts = ids.compactMap { model.position(of: $0) }
            guard pts.count == ids.count, pts.count >= 2 else { return nil }
            let samples = SplineEvaluator.sample(points: pts, mode: mode,
                                                 perSegment: splineSamplesPerSegment)
            return CurveGeometry(curveID: curve.id, shape: .sampledSpline(samples: samples))
        }
    }

    // MARK: - Evaluación

    /// Punto en t ∈ [0,1].
    public func evaluate(_ t: Double) -> Vec2 {
        let t = min(1, max(0, t))
        switch shape {
        case .line(let a, let b):
            return Vec2.lerp(a, b, t)
        case .arc(let c, let r, let a0, let sweep, let ccw):
            let ang = ccw ? a0 + sweep * t : a0 - sweep * t
            return c + Vec2(cos(ang), sin(ang)) * r
        case .circle(let c, let r):
            let ang = 2 * .pi * t
            return c + Vec2(cos(ang), sin(ang)) * r
        case .sampledSpline(let s):
            guard s.count >= 2 else { return s.first ?? .zero }
            let ft = t * Double(s.count - 1)
            let i = min(s.count - 2, Int(ft))
            return Vec2.lerp(s[i], s[i + 1], ft - Double(i))
        }
    }

    /// Tangente unitaria en t (dirección de avance del trazado).
    public func tangent(_ t: Double) -> Vec2 {
        switch shape {
        case .line(let a, let b):
            return (b - a).normalized
        case .arc(let _, _, let a0, let sweep, let ccw):
            let ang = ccw ? a0 + sweep * t : a0 - sweep * t
            let radial = Vec2(cos(ang), sin(ang))
            return ccw ? radial.perpendicular : -radial.perpendicular
        case .circle:
            let e = 1e-5
            return (evaluate(min(1, t + e)) - evaluate(max(0, t - e))).normalized
        case .sampledSpline:
            let e = 1e-4
            return (evaluate(min(1, t + e)) - evaluate(max(0, t - e))).normalized
        }
    }

    // MARK: - Distancia / punto más cercano

    public struct Closest: Sendable {
        public let point: Vec2
        public let t: Double
        public let distance: Double
    }

    public func closestPoint(to p: Vec2) -> Closest {
        switch shape {
        case .line(let a, let b):
            let ab = b - a
            let len2 = ab.lengthSquared
            let t = len2 < 1e-18 ? 0 : min(1, max(0, (p - a).dot(ab) / len2))
            let q = a + ab * t
            return Closest(point: q, t: t, distance: p.distance(to: q))

        case .circle(let c, let r):
            let d = p - c
            let q = d.lengthSquared < 1e-18 ? c + Vec2(r, 0) : c + d.normalized * r
            var t = (q - c).angle / (2 * .pi)
            if t < 0 { t += 1 }
            return Closest(point: q, t: t, distance: p.distance(to: q))

        case .arc(let c, let r, let a0, let sweep, let ccw):
            let d = p - c
            if d.lengthSquared < 1e-18 {
                let q = evaluate(0)
                return Closest(point: q, t: 0, distance: p.distance(to: q))
            }
            let ang = d.angle
            // Normalizar el ángulo del cursor al parámetro del arco
            var delta = ccw ? ang - a0 : a0 - ang
            while delta < 0 { delta += 2 * .pi }
            while delta >= 2 * .pi { delta -= 2 * .pi }
            if delta <= sweep {
                let t = delta / sweep
                let q = c + d.normalized * r
                return Closest(point: q, t: t, distance: p.distance(to: q))
            }
            // Fuera del barrido: el extremo más cercano
            let s = evaluate(0), e = evaluate(1)
            return p.distance(to: s) <= p.distance(to: e)
                ? Closest(point: s, t: 0, distance: p.distance(to: s))
                : Closest(point: e, t: 1, distance: p.distance(to: e))

        case .sampledSpline(let samples):
            var best = Closest(point: samples[0], t: 0, distance: p.distance(to: samples[0]))
            for i in 0..<(samples.count - 1) {
                let a = samples[i], b = samples[i + 1]
                let ab = b - a
                let len2 = ab.lengthSquared
                let tSeg = len2 < 1e-18 ? 0 : min(1, max(0, (p - a).dot(ab) / len2))
                let q = a + ab * tSeg
                let d = p.distance(to: q)
                if d < best.distance {
                    let t = (Double(i) + tSeg) / Double(samples.count - 1)
                    best = Closest(point: q, t: t, distance: d)
                }
            }
            return best
        }
    }

    // MARK: - Puntos notables (alimentan el snap)

    /// Punto medio de la curva (círculo no tiene).
    public var midpoint: Vec2? {
        switch shape {
        case .circle: return nil
        default: return evaluate(0.5)
        }
    }

    /// Centro (círculo/arco).
    public var center: Vec2? {
        switch shape {
        case .circle(let c, _): return c
        case .arc(let c, _, _, _, _): return c
        default: return nil
        }
    }

    /// Cuadrantes N/E/S/O de círculos (y los que caen dentro del barrido de arcos).
    public var quadrants: [Vec2] {
        switch shape {
        case .circle(let c, let r):
            return [c + Vec2(r, 0), c + Vec2(0, r), c + Vec2(-r, 0), c + Vec2(0, -r)]
        case .arc(let c, let r, let a0, let sweep, let ccw):
            var result: [Vec2] = []
            for k in 0..<4 {
                let qa = Double(k) * .pi / 2
                var delta = ccw ? qa - a0 : a0 - qa
                while delta < 0 { delta += 2 * .pi }
                while delta >= 2 * .pi { delta -= 2 * .pi }
                if delta <= sweep { result.append(c + Vec2(cos(qa), sin(qa)) * r) }
            }
            return result
        default:
            return []
        }
    }

    // MARK: - Discretización (regiones, intersecciones con splines, render)

    /// Polilínea que aproxima la curva con flecha (sagitta) ≤ maxDeviation.
    public func discretize(maxDeviation: Double = 1e-3) -> [Vec2] {
        switch shape {
        case .line(let a, let b):
            return [a, b]
        case .sampledSpline(let s):
            return s
        case .circle(let c, let r):
            let n = Self.arcSegments(radius: r, sweep: 2 * .pi, maxDeviation: maxDeviation)
            var pts: [Vec2] = []
            for k in 0...n {
                let ang = 2 * .pi * Double(k) / Double(n)
                pts.append(c + Vec2(cos(ang), sin(ang)) * r)
            }
            return pts
        case .arc(let c, let r, let a0, let sweep, let ccw):
            let n = Self.arcSegments(radius: r, sweep: sweep, maxDeviation: maxDeviation)
            var pts: [Vec2] = []
            for k in 0...n {
                let t = Double(k) / Double(n)
                let ang = ccw ? a0 + sweep * t : a0 - sweep * t
                pts.append(c + Vec2(cos(ang), sin(ang)) * r)
            }
            return pts
        }
    }

    /// Segmentos para que la cuerda no se separe del arco más de maxDeviation.
    static func arcSegments(radius: Double, sweep: Double, maxDeviation: Double) -> Int {
        guard radius > 1e-12, maxDeviation > 0 else { return 8 }
        let ratio = max(0, 1 - maxDeviation / radius)
        let maxStep = 2 * acos(min(1, ratio))
        guard maxStep > 1e-9 else { return 512 }
        return max(8, min(512, Int(ceil(sweep / maxStep))))
    }

    public var boundingBox: BBox2 {
        BBox2(of: discretize(maxDeviation: 1e-3))
    }
}

/// Evaluador de splines — los dos modos de Shapr3D.
public enum SplineEvaluator {
    /// Muestrea la spline como polilínea densa.
    public static func sample(points: [Vec2], mode: SplineMode, perSegment: Int = 16) -> [Vec2] {
        guard points.count >= 2 else { return points }
        switch mode {
        case .throughPoints: return sampleCatmullRom(points, perSegment: perSegment)
        case .controlPoints: return sampleClampedBSpline(points, perSegment: perSegment)
        }
    }

    /// Catmull-Rom CENTRÍPETA (α=0.5): pasa por todos los puntos, sin bucles ni
    /// cúspides en puntos apretados — la interpolada estándar de las apps CAD.
    static func sampleCatmullRom(_ pts: [Vec2], perSegment: Int) -> [Vec2] {
        if pts.count == 2 { return [pts[0], pts[1]] }
        // Extremos fantasma por reflexión para que la curva llegue a los bordes
        let first = pts[0] * 2 - pts[1]
        let last = pts[pts.count - 1] * 2 - pts[pts.count - 2]
        let p = [first] + pts + [last]

        var out: [Vec2] = [pts[0]]
        for i in 1..<(p.count - 2) {
            let p0 = p[i - 1], p1 = p[i], p2 = p[i + 1], p3 = p[i + 2]
            // Parametrización centrípeta
            func tj(_ ti: Double, _ a: Vec2, _ b: Vec2) -> Double {
                ti + a.distance(to: b).squareRoot()
            }
            let t0 = 0.0
            let t1 = tj(t0, p0, p1)
            let t2 = tj(t1, p1, p2)
            let t3 = tj(t2, p2, p3)
            guard t1 > t0 + 1e-12, t2 > t1 + 1e-12, t3 > t2 + 1e-12 else {
                out.append(p2); continue
            }
            for k in 1...perSegment {
                let t = t1 + (t2 - t1) * Double(k) / Double(perSegment)
                let a1 = Vec2.lerp(p0, p1, (t - t0) / (t1 - t0))
                let a2 = Vec2.lerp(p1, p2, (t - t1) / (t2 - t1))
                let a3 = Vec2.lerp(p2, p3, (t - t2) / (t3 - t2))
                let b1 = Vec2.lerp(a1, a2, (t - t0) / (t2 - t0))
                let b2 = Vec2.lerp(a2, a3, (t - t1) / (t3 - t1))
                out.append(Vec2.lerp(b1, b2, (t - t1) / (t2 - t1)))
            }
        }
        return out
    }

    /// B-spline cúbica SUJETA (clamped): empieza y termina en el primer/último
    /// punto de control; el resto del polígono atrae la curva — el modo
    /// "puntos de control" de Shapr3D. De Boor sobre knots sujetos.
    static func sampleClampedBSpline(_ ctrl: [Vec2], perSegment: Int) -> [Vec2] {
        let n = ctrl.count
        if n == 2 { return [ctrl[0], ctrl[1]] }
        let degree = min(3, n - 1)
        // Knots sujetos: degree+1 ceros, interiores uniformes, degree+1 unos
        var knots: [Double] = Array(repeating: 0, count: degree + 1)
        let interior = n - degree - 1
        if interior > 0 {
            for i in 1...interior { knots.append(Double(i) / Double(interior + 1)) }
        }
        knots.append(contentsOf: Array(repeating: 1, count: degree + 1))

        func deBoor(_ t: Double) -> Vec2 {
            // Índice del tramo de knots que contiene t
            var k = degree
            while k < n - 1 && t >= knots[k + 1] { k += 1 }
            var d: [Vec2] = []
            for j in 0...degree { d.append(ctrl[j + k - degree]) }
            for r in 1...degree {
                for j in stride(from: degree, through: r, by: -1) {
                    let i = j + k - degree
                    let denom = knots[i + degree + 1 - r] - knots[i]
                    let alpha = denom < 1e-12 ? 0 : (t - knots[i]) / denom
                    d[j] = d[j - 1] * (1 - alpha) + d[j] * alpha
                }
            }
            return d[degree]
        }

        let totalSamples = max(2, perSegment * (n - 1))
        var out: [Vec2] = []
        for k in 0...totalSamples {
            let t = Double(k) / Double(totalSamples)
            out.append(deBoor(min(t, 1 - 1e-12)))
        }
        out[out.count - 1] = ctrl[n - 1] // extremo exacto
        return out
    }
}
