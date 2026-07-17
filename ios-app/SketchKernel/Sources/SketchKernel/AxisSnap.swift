import Foundation

/// Commit H/V DEFINITIVO — regla <10° de Dune3D (`get_auto_constraint` en
/// `tool_draw_contour.cpp`). Al confirmar una línea, si el ángulo del segmento
/// respecto al punto de referencia está a menos de `thresholdDegrees` de la
/// horizontal o vertical, el extremo se ajusta al eje exacto. Es lógica pura
/// (sin estado ni UI) para poder testarla en el kernel; el controlador la llama
/// con `allowAdjust=false` cuando hubo un snap "duro" (endpoint/intersección/
/// medio/centro/cuadrante), porque entonces la posición fue intencional.
public enum AxisSnap {

    /// Endereza `endpoint` a H/V exacto respecto a `reference` si el ángulo cae
    /// dentro del umbral y `allowAdjust` es true. Devuelve el punto sin cambios
    /// en cualquier otro caso.
    public static func commit(endpoint: Vec2, reference: Vec2,
                              allowAdjust: Bool = true,
                              thresholdDegrees: Double = 10) -> Vec2 {
        guard allowAdjust else { return endpoint }
        let d = endpoint - reference
        guard d.length > 1e-9 else { return endpoint }
        let ang = abs(atan2(d.y, d.x))               // [0, π]
        let toHorizontal = min(ang, .pi - ang)       // distancia a 0° / 180°
        let toVertical = abs(ang - .pi / 2)          // distancia a 90°
        let threshold = thresholdDegrees * .pi / 180.0
        if toHorizontal <= threshold && toHorizontal <= toVertical {
            return Vec2(endpoint.x, reference.y)     // horizontal exacta
        } else if toVertical <= threshold {
            return Vec2(reference.x, endpoint.y)     // vertical exacta
        }
        return endpoint
    }
}
