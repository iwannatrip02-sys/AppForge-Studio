import Foundation

/// Edición numérica de líneas al dibujar ("curva caliente"): longitud y ángulo.
/// Mover el ENDPOINT (el punto final; el inicial queda fijo) vía `movePoint`
/// arrastra por topología todo lo que comparta ese punto. Brecha #1 de
/// sensación vs Shapr3D (input numérico al dibujar, inspirado en FreeCAD).
extension SketchModel {

    /// Longitud y ángulo (grados respecto a +X) de una línea, con sus PointID.
    /// nil si la curva no es una línea o faltan posiciones.
    public func lineMetrics(_ id: CurveID) -> (length: Double, angleDegrees: Double,
                                               start: PointID, end: PointID)? {
        guard case .line(let s, let e)? = curves[id]?.kind,
              let sp = positions[s], let ep = positions[e] else { return nil }
        let d = ep - sp
        let len = d.length
        let ang = atan2(d.y, d.x) * 180 / .pi
        return (len, ang, s, e)
    }

    /// Fija la LONGITUD de una línea moviendo el endpoint a lo largo de su
    /// dirección actual (el inicio queda fijo). Si la línea es degenerada (los
    /// dos puntos coinciden) usa +X como dirección por defecto.
    public mutating func setLineLength(_ id: CurveID, _ length: Double) {
        guard let m = lineMetrics(id), length > 1e-9,
              let sp = positions[m.start] else { return }
        let dir: Vec2
        if m.length > 1e-9, let ep = positions[m.end] {
            dir = (ep - sp).normalized
        } else {
            dir = Vec2(1, 0)
        }
        movePoint(m.end, to: sp + dir * length)
    }

    /// Fija el ÁNGULO (grados respecto a +X) de una línea rotando el endpoint
    /// alrededor del inicio, conservando la longitud actual.
    public mutating func setLineAngle(_ id: CurveID, degrees: Double) {
        guard let m = lineMetrics(id), let sp = positions[m.start] else { return }
        let len = m.length > 1e-9 ? m.length : 1
        let rad = degrees * .pi / 180
        movePoint(m.end, to: sp + Vec2(cos(rad), sin(rad)) * len)
    }
}
