import Foundation

/// Vector 2D en Double. El kernel trabaja en Double (precisión CAD);
/// la app convierte a SIMD2<Float> solo en la frontera de render.
public struct Vec2: Hashable, Sendable, Codable {
    public var x: Double
    public var y: Double

    public init(_ x: Double, _ y: Double) { self.x = x; self.y = y }
    public init(x: Double, y: Double) { self.x = x; self.y = y }

    public static let zero = Vec2(0, 0)

    public static func + (a: Vec2, b: Vec2) -> Vec2 { Vec2(a.x + b.x, a.y + b.y) }
    public static func - (a: Vec2, b: Vec2) -> Vec2 { Vec2(a.x - b.x, a.y - b.y) }
    public static func * (a: Vec2, s: Double) -> Vec2 { Vec2(a.x * s, a.y * s) }
    public static func * (s: Double, a: Vec2) -> Vec2 { Vec2(a.x * s, a.y * s) }
    public static func / (a: Vec2, s: Double) -> Vec2 { Vec2(a.x / s, a.y / s) }
    public static prefix func - (a: Vec2) -> Vec2 { Vec2(-a.x, -a.y) }
    public static func += (a: inout Vec2, b: Vec2) { a = a + b }
    public static func -= (a: inout Vec2, b: Vec2) { a = a - b }

    public func dot(_ b: Vec2) -> Double { x * b.x + y * b.y }
    /// Componente z del producto cruz 3D — signo = lado (izq/der).
    public func cross(_ b: Vec2) -> Double { x * b.y - y * b.x }

    public var lengthSquared: Double { x * x + y * y }
    public var length: Double { (x * x + y * y).squareRoot() }

    public func distance(to b: Vec2) -> Double { (self - b).length }
    public func distanceSquared(to b: Vec2) -> Double { (self - b).lengthSquared }

    public var normalized: Vec2 {
        let l = length
        return l > 1e-12 ? self / l : Vec2(1, 0)
    }

    /// Perpendicular CCW (rotación +90°).
    public var perpendicular: Vec2 { Vec2(-y, x) }

    /// Ángulo polar en radianes, rango (-π, π].
    public var angle: Double { atan2(y, x) }

    public static func lerp(_ a: Vec2, _ b: Vec2, _ t: Double) -> Vec2 {
        a + (b - a) * t
    }

    public func rotated(by radians: Double) -> Vec2 {
        let c = cos(radians), s = sin(radians)
        return Vec2(x * c - y * s, x * s + y * c)
    }
}

/// Caja alineada a ejes — culling y hit-test grueso.
public struct BBox2: Sendable, Codable {
    public var min: Vec2
    public var max: Vec2

    public init(min: Vec2, max: Vec2) { self.min = min; self.max = max }

    public init(of points: [Vec2]) {
        var lo = Vec2(.infinity, .infinity)
        var hi = Vec2(-.infinity, -.infinity)
        for p in points {
            lo.x = Swift.min(lo.x, p.x); lo.y = Swift.min(lo.y, p.y)
            hi.x = Swift.max(hi.x, p.x); hi.y = Swift.max(hi.y, p.y)
        }
        self.min = lo; self.max = hi
    }

    public func expanded(by r: Double) -> BBox2 {
        BBox2(min: Vec2(min.x - r, min.y - r), max: Vec2(max.x + r, max.y + r))
    }

    public func contains(_ p: Vec2) -> Bool {
        p.x >= min.x && p.x <= max.x && p.y >= min.y && p.y <= max.y
    }
}
