import SwiftUI
import simd

// =============================================================================
// TransformHUD — número vivo flotante anclado al gizmo (Ola LiveInteraction · L2 · tarea 1)
// =============================================================================
//
// Muestra `transformReadout` EN VIVO (mono grande, ember) sobre el viewport 3D,
// anclado al centro del gizmo proyectado con `ViewportProjector`. Un TAP sobre el
// número lo vuelve editable (NumericField) para aplicar un valor exacto. Reemplaza
// el `default: EmptyView()` del parameterBar para move/rotate/scale: el número deja
// de ser estado huérfano y se convierte en el foco Shapr3D del gesto.
//
// Consume el DESIGN SYSTEM: ForgeGlass + `.glassPanel(context: .hud)` (que YA existe).

/// HUD flotante del transform. Se ancla a un punto 3D (centro del gizmo) proyectado
/// a pantalla; si el punto cae detrás de cámara, no se dibuja.
struct TransformHUD: View {
    /// Centro del gizmo en MUNDO (centroide del objetivo activo). nil ⇒ oculto.
    let worldCenter: SIMD3<Float>?
    /// Proyector mundo→pantalla (mismas matrices que el renderer).
    let projector: ViewportProjector
    /// Lectura viva ya formateada (distancia / ángulo / factor).
    let readout: String
    /// ¿El valor está pegado a un detente de snap? Cambia el color (feedback tarea 2).
    let isSnapped: Bool
    /// ¿Hay un gesto de transform en curso? Controla la aparición del HUD.
    let isActive: Bool
    /// Empujón numérico editable (unidades de mundo) — TAP sobre el número lo edita.
    @Binding var nudge: Double
    /// Rango permitido para el campo editable.
    var nudgeRange: ClosedRange<Double> = -1000...1000
    /// Se llama al confirmar la edición (soltar/return) para refrescar el preview.
    var onCommitEdit: () -> Void

    @State private var editing = false

    var body: some View {
        // Sin gesto activo o punto detrás de cámara → nada que dibujar.
        if isActive, let center = worldCenter, let p = projector.project(center) {
            content
                .position(x: p.x, y: max(48, p.y - 56))  // flota ~56pt sobre el gizmo
                .animation(ForgeGlass.Motion.snappy, value: isSnapped)
                .allowsHitTesting(true)
                .accessibilityIdentifier("transform.hud")
        }
    }

    private var numberColor: SwiftUI.Color {
        // Al snapear, el número vira a acero (confirmación de detente) — el resto
        // del tiempo es la brasa viva. Firma de estado del Design System.
        isSnapped ? ForgeGlass.Color.steel : ForgeGlass.Color.ember
    }

    @ViewBuilder
    private var content: some View {
        HStack(spacing: ForgeGlass.Spacing.s2) {
            if editing {
                // Campo editable: aplicar un valor EXACTO al soltar/confirmar.
                NumericField(value: $nudge, range: nudgeRange, format: "%+.2f")
                    .onSubmit {
                        editing = false
                        onCommitEdit()
                    }
                Button {
                    editing = false
                    onCommitEdit()
                } label: {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: ForgeGlass.Icon.md, weight: .semibold))
                        .foregroundColor(ForgeGlass.Color.ember)
                }
                .accessibilityLabel("Aplicar valor")
            } else {
                // Número vivo grande: TAP → editable.
                Text(readout.isEmpty ? "0.00" : readout)
                    .font(ForgeGlass.Typography.numberLive.font)
                    .foregroundColor(numberColor)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .onTapGesture {
                        HapticService.shared.selection()
                        editing = true
                    }
                    .accessibilityLabel("Medida viva")
                    .accessibilityValue(readout)
            }
        }
        .padding(.horizontal, ForgeGlass.Spacing.s3)
        .padding(.vertical, ForgeGlass.Spacing.s2)
        .glassPanel(context: .hud)
        .emberGlow(active: isSnapped)
        .fixedSize()
    }
}
