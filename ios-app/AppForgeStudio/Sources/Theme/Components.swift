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

// MARK: View Extensions

extension View {
    func glassPanel() -> some View { modifier(GlassPanelModifier()) }
    func surfaceCard() -> some View { modifier(SurfaceCardModifier()) }
    func toolbarGlow(active: Bool = false) -> some View { modifier(ToolbarGlowModifier(active: active)) }
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
