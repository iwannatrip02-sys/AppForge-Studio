import SwiftUI

// MARK: - C10 Canonical Components
// GlassPanel, ToolButton, ParamSlider — unified design system widgets

// MARK: GlassPanel Modifier

/// Floating translucent panel: .ultraThinMaterial + bgGlass + border 0.5px + shadow level2
struct GlassPanelModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(.ultraThinMaterial)
            .background(AppTheme.bgGlass)
            .cornerRadius(AppTheme.radiusMD)
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.radiusMD)
                    .stroke(AppTheme.borderColor, lineWidth: 0.5)
            )
            .shadow(
                color: AppTheme.Elevation.level2.shadow.color,
                radius: AppTheme.Elevation.level2.shadow.radius,
                y: AppTheme.Elevation.level2.shadow.y
            )
    }
}

// MARK: SurfaceCard Modifier

/// Elevated card: bgRaised + radiusLG + border 0.5px + shadow level1
struct SurfaceCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(AppTheme.bgRaised)
            .cornerRadius(AppTheme.radiusLG)
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.radiusLG)
                    .stroke(AppTheme.borderColor, lineWidth: 0.5)
            )
            .shadow(
                color: AppTheme.Elevation.level1.shadow.color,
                radius: AppTheme.Elevation.level1.shadow.radius,
                y: AppTheme.Elevation.level1.shadow.y
            )
    }
}

// MARK: ToolbarGlow Modifier

/// Active tool highlight: accent fill + border
struct ToolbarGlowModifier: ViewModifier {
    var active: Bool = false
    func body(content: Content) -> some View {
        content
            .background(active ? AppTheme.accentColor.opacity(0.15) : Color.clear)
            .cornerRadius(AppTheme.radiusSM)
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.radiusSM)
                    .stroke(active ? AppTheme.accentColor.opacity(0.30) : Color.clear, lineWidth: 1)
            )
    }
}

// MARK: Tempered Modifier — firma de identidad (IDENTIDAD_FORGE §6)

/// "El templado": al confirmar una operación, el elemento flashea brasa→acero
/// en 400ms. Confirmación física sin toasts. Se dispara incrementando `trigger`.
struct TemperedModifier: ViewModifier {
    let trigger: Int
    @State private var glow = false

    func body(content: Content) -> some View {
        content
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.radiusMD)
                    .stroke(AppTheme.accentColor, lineWidth: 2)
                    .opacity(glow ? 0.9 : 0)
                    .allowsHitTesting(false)
            )
            .onChange(of: trigger) { _ in
                glow = true
                withAnimation(.easeOut(duration: 0.4)) { glow = false }
            }
    }
}

// MARK: VerticalParamSlider — control lateral de pulgar (BLUEPRINT N1)

/// Slider vertical flotante pegado al borde del viewport: los 2 parámetros que
/// cambias 200 veces por sesión (radio/fuerza) sin un solo tap de navegación.
/// Brasa mientras arrastras (estado activo), acero en reposo.
struct VerticalParamSlider: View {
    @Binding var value: Float
    let range: ClosedRange<Float>
    var icon: String = "circle.dashed"
    var format: String = "%.2f"

    @State private var dragging = false
    private let trackHeight: CGFloat = 140

    private var normalized: CGFloat {
        CGFloat((value - range.lowerBound) / max(range.upperBound - range.lowerBound, 0.0001))
    }

    var body: some View {
        VStack(spacing: AppTheme.space2) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundColor(dragging ? AppTheme.accentColor : AppTheme.textTertiary)
            ZStack(alignment: .bottom) {
                Capsule().fill(AppTheme.bgOverlay).frame(width: 5)
                Capsule()
                    .fill(dragging ? AppTheme.accentColor : AppTheme.steel)
                    .frame(width: 5, height: max(6, normalized * trackHeight))
            }
            .frame(width: 30, height: trackHeight)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { g in
                        if !dragging { HapticService.shared.light() }
                        dragging = true
                        let t = 1 - min(max(g.location.y / trackHeight, 0), 1)
                        value = range.lowerBound + Float(t) * (range.upperBound - range.lowerBound)
                    }
                    .onEnded { _ in dragging = false }
            )
            Text(String(format: format, value))
                .font(AppTheme.Typography.mono.font)
                .foregroundColor(dragging ? AppTheme.accentColor : AppTheme.textTertiary)
                .frame(width: 34)
        }
        .padding(.vertical, AppTheme.space2)
        .padding(.horizontal, 2)
        .glassPanel()
    }
}

// MARK: NumericField — valor vivo EDITABLE (BLUEPRINT S3, precisión CAD)

/// El número junto al slider deja de ser texto: tócalo y escribe el valor
/// exacto (teclado decimal). Une el feel táctil con la precisión de ingeniería.
struct NumericField: View {
    @Binding var value: Double
    var range: ClosedRange<Double> = 0.001...1000
    var format: String = "%.2f"

    @State private var text = ""
    @FocusState private var focused: Bool

    var body: some View {
        TextField("", text: $text)
            .keyboardType(.numbersAndPunctuation)
            .multilineTextAlignment(.trailing)
            .font(AppTheme.Typography.monoLarge.font)
            .foregroundColor(focused ? AppTheme.accentColor : AppTheme.textPrimaryColor)
            .frame(width: 64)
            .padding(.vertical, 2).padding(.horizontal, 4)
            .background(focused ? AppTheme.accentColor.opacity(0.12) : AppTheme.bgOverlay)
            .cornerRadius(AppTheme.radiusSM)
            .focused($focused)
            .onAppear { text = String(format: format, value) }
            .onChange(of: value) { v in
                if !focused { text = String(format: format, v) }
            }
            .onChange(of: text) { t in
                guard focused else { return }
                if let v = Double(t.replacingOccurrences(of: ",", with: ".")) {
                    value = min(max(v, range.lowerBound), range.upperBound)
                }
            }
            .onSubmit {
                focused = false
                text = String(format: format, value)
            }
    }
}

// MARK: View Extensions

extension View {
    func glassPanel() -> some View { modifier(GlassPanelModifier()) }
    func surfaceCard() -> some View { modifier(SurfaceCardModifier()) }
    func toolbarGlow(active: Bool = false) -> some View { modifier(ToolbarGlowModifier(active: active)) }
    /// Flash brasa→acero al confirmar una operación (incrementa `trigger` para disparar).
    func tempered(trigger: Int) -> some View { modifier(TemperedModifier(trigger: trigger)) }
}

// MARK: - ToolButton (Canonical Toolbar Button)

/// Toolbar button with icon + optional label, 48×48pt touch target, accent active state
struct ToolButton: View {
    let icon: String
    let label: String?
    let isActive: Bool
    let action: () -> Void

    init(icon: String, label: String? = nil, isActive: Bool = false, action: @escaping () -> Void) {
        self.icon = icon
        self.label = label
        self.isActive = isActive
        self.action = action
    }

    var body: some View {
        Button(action: {
            HapticService.shared.light()
            action()
        }) {
            VStack(spacing: 2) {
                Image(systemName: icon)
                    .font(.system(size: AppTheme.iconMD,
                                  weight: isActive ? .medium : .regular))
                    .frame(width: AppTheme.touchComfortable,
                           height: AppTheme.touchComfortable)
                if let label = label {
                    Text(label)
                        .font(AppTheme.Typography.toolLabel.font)
                        .lineLimit(1)
                }
            }
            .foregroundColor(isActive ? AppTheme.accentColor : AppTheme.textTertiary)
            .background(isActive ? AppTheme.accentColor.opacity(0.15) : Color.clear)
            .cornerRadius(AppTheme.radiusSM)
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.radiusSM)
                    .stroke(isActive ? AppTheme.accentColor.opacity(0.30) : Color.clear,
                            lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label ?? icon)
    }
}

// MARK: - ParamSlider (Parameter Slider with Label)

/// Labeled slider: caption + mono value + accent tint
struct ParamSlider: View {
    let label: String
    @Binding var value: Float
    let range: ClosedRange<Float>
    let unit: String
    let step: Float

    init(label: String, value: Binding<Float>, range: ClosedRange<Float>, unit: String = "", step: Float = 0.01) {
        self.label = label
        self._value = value
        self.range = range
        self.unit = unit
        self.step = step
    }

    var body: some View {
        VStack(spacing: AppTheme.space2) {
            HStack {
                Text(label)
                    .font(AppTheme.Typography.caption.font)
                    .foregroundColor(AppTheme.textTertiary)
                Spacer()
                Text(unit.isEmpty
                     ? "\(value, specifier: "%.2f")"
                     : "\(value, specifier: "%.2f") \(unit)")
                    .font(AppTheme.Typography.mono.font)
                    .foregroundColor(AppTheme.textPrimaryColor)
            }
            Slider(value: $value, in: range, step: Float.Stride(step))
                .tint(AppTheme.accentColor)
        }
    }
}

// MARK: - Previews

#if DEBUG
struct Components_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            AppTheme.bgCanvas.ignoresSafeArea()
            VStack(spacing: AppTheme.space4) {
                ToolButton(icon: "cube.transparent", label: "CAD", isActive: true) {}
                ToolButton(icon: "scribble.variable", label: "Sculpt", isActive: false) {}
                ParamSlider(
                    label: "Radius",
                    value: .constant(2.5),
                    range: 0.01...50,
                    unit: "mm"
                )
                .frame(width: 200)
            }
            .glassPanel()
            .padding()
        }
        .preferredColorScheme(.dark)
    }
}
#endif
