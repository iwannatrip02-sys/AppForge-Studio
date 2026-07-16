import SwiftUI
import simd

// =============================================================================
// TransformSnapGuide — guía de eje + ticks de incremento (Ola LiveInteraction · L2 · tarea 2)
// =============================================================================
//
// Durante un drag de transform con snap activo, dibuja la LÍNEA-GUÍA del eje
// restringido que pasa por el centro del gizmo, con TICKS en cada incremento de
// rejilla, todo proyectado a pantalla con `ViewportProjector`. El snap ya cuantiza
// el valor (matemática en `TransformSnap`); esto lo hace VISIBLE — el usuario ve
// hacia dónde se moverá y dónde caen los detentes.
//
// El HUD (número) y el haptic viven en otros componentes; aquí solo la geometría
// de la guía. Se dibuja con `Canvas` (barato, sin hit-testing).

struct TransformSnapGuide: View {
    /// Centro del gizmo en MUNDO (origen de la guía). nil ⇒ oculto.
    let worldCenter: SIMD3<Float>?
    /// Eje restringido YA resuelto a MUNDO (respeta local/global). nil ⇒ sin guía
    /// (drag libre: no hay un único eje que dibujar).
    let worldAxis: SIMD3<Float>?
    /// Proyector mundo→pantalla (mismas matrices que el renderer).
    let projector: ViewportProjector
    /// Paso de rejilla en unidades de mundo (distancia entre ticks).
    let gridStep: Double
    /// ¿Guía activa? (gesto en curso + snap activado).
    let isActive: Bool
    /// ¿El valor está pegado a un detente ahora? Ilumina la guía (feedback).
    let isSnapped: Bool

    /// Cuántos ticks dibujar a cada lado del centro (media longitud de la guía).
    private let ticksPerSide = 8

    private var lineColor: SwiftUI.Color {
        isSnapped ? ForgeGlass.Color.steel : ForgeGlass.Color.ember
    }

    var body: some View {
        Canvas { context, _ in
            guard isActive,
                  let center = worldCenter,
                  let axis = worldAxis,
                  simd_length(axis) > 1e-5,
                  gridStep > 1e-6 else { return }

            let a = simd_normalize(axis)
            let step = Float(gridStep)

            // Extremos de la línea-guía (± ticksPerSide pasos desde el centro).
            let reach = Float(ticksPerSide) * step
            guard let p0 = projector.project(center - a * reach),
                  let p1 = projector.project(center + a * reach) else { return }

            var line = Path()
            line.move(to: p0)
            line.addLine(to: p1)
            context.stroke(line,
                           with: .color(lineColor.opacity(0.85)),
                           style: StrokeStyle(lineWidth: 1.5, dash: [6, 5]))

            // Ticks de incremento: un pequeño segmento perpendicular en cada detente.
            for k in -ticksPerSide...ticksPerSide {
                let worldTick = center + a * (Float(k) * step)
                guard let screen = projector.project(worldTick) else { continue }
                let size: CGFloat = (k == 0) ? 7 : 4
                var tick = Path()
                tick.addEllipse(in: CGRect(x: screen.x - size / 2,
                                           y: screen.y - size / 2,
                                           width: size, height: size))
                let fill = (k == 0) ? lineColor : lineColor.opacity(0.6)
                context.fill(tick, with: .color(fill))
            }
        }
        .allowsHitTesting(false)
        .opacity(isActive ? 1 : 0)
        .animation(ForgeGlass.Motion.snappy, value: isActive)
        .animation(ForgeGlass.Motion.snappy, value: isSnapped)
    }
}
