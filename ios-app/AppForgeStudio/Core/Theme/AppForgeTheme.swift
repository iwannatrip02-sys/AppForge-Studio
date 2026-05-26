import SwiftUI

// MARK: - Shapr3D-Inspired Professional Design System
// Key principles: glass-morphism, 8pt grid, SF Pro typography, spring animations, depth

struct AppForgeTheme {
    // ── Backgrounds (dark, layered, OLED-friendly) ──
    static let bgCanvas    = Color(hex: "0A0A0F")  // Deepest: viewport bg
    static let bgBase      = Color(hex: "121218")  // Main surface
    static let bgRaised    = Color(hex: "1A1A24")  // Cards, panels
    static let bgOverlay   = Color(hex: "22222E")  // Hover, active states
    static let bgGlass     = Color(hex: "1C1C28").opacity(0.85)  // Glass panels
    
    // ── Accent (Shapr3D blue) ──
    static let accent      = Color(hex: "4DA3FF")  // Primary action blue
    static let accentMuted = Color(hex: "3A7ACC")  // Secondary
    static let accentGlow  = Color(hex: "6DB9FF")  // Highlight
    
    // ── Semantic ──
    static let success     = Color(hex: "34D399")
    static let warning     = Color(hex: "FBBF24")
    static let error       = Color(hex: "F87171")
    static let axisRed     = Color(hex: "F87171")
    static let axisGreen   = Color(hex: "34D399")
    static let axisBlue    = Color(hex: "4DA3FF")
    
    // ── Text ──
    static let textPri     = Color(hex: "F0F0F5")  // Primary white
    static let textSec     = Color(hex: "9A9AB0")  // Secondary gray
    static let textTer     = Color(hex: "5A5A6E")  // Tertiary/dim
    
    // ── Borders ──
    static let border      = Color(hex: "2A2A3A")
    static let borderLight = Color(hex: "1E1E2E")
    
    // ── Spacing (8pt grid) ──
    static let spXXS: CGFloat = 2
    static let spXS:  CGFloat = 4
    static let spSM:  CGFloat = 8
    static let spMD:  CGFloat = 12
    static let spLG:  CGFloat = 16
    static let spXL:  CGFloat = 24
    static let spXXL: CGFloat = 32
    
    // ── Radii ──
    static let rSM: CGFloat = 6
    static let rMD: CGFloat = 10
    static let rLG: CGFloat = 14
    static let rXL: CGFloat = 20
    
    // ── Typography ──
    static func title(_ text: String) -> some View {
        Text(text).font(.system(size: 15, weight: .semibold, design: .default))
            .foregroundColor(textPri)
    }
    static func heading(_ text: String) -> some View {
        Text(text).font(.system(size: 12, weight: .medium, design: .default))
            .foregroundColor(textSec)
    }
    static func label(_ text: String) -> some View {
        Text(text).font(.system(size: 10, weight: .regular, design: .default))
            .foregroundColor(textTer)
    }
    static func mono(_ text: String) -> some View {
        Text(text).font(.system(size: 10, weight: .medium, design: .monospaced))
            .foregroundColor(textSec)
    }
}

// MARK: - View Modifiers (Glass, Shadow, Animation)

struct GlassPanel: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(.ultraThinMaterial)
            .background(AppForgeTheme.bgGlass)
            .cornerRadius(AppForgeTheme.rMD)
            .overlay(
                RoundedRectangle(cornerRadius: AppForgeTheme.rMD)
                    .stroke(AppForgeTheme.border, lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.3), radius: 8, y: 2)
    }
}

struct ToolbarGlow: ViewModifier {
    var active: Bool = false
    func body(content: Content) -> some View {
        content
            .background(active ? AppForgeTheme.accent.opacity(0.15) : Color.clear)
            .cornerRadius(AppForgeTheme.rSM)
            .overlay(
                RoundedRectangle(cornerRadius: AppForgeTheme.rSM)
                    .stroke(active ? AppForgeTheme.accent.opacity(0.3) : Color.clear, lineWidth: 1)
            )
    }
}

struct SurfaceCard: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(AppForgeTheme.bgRaised)
            .cornerRadius(AppForgeTheme.rLG)
            .overlay(
                RoundedRectangle(cornerRadius: AppForgeTheme.rLG)
                    .stroke(AppForgeTheme.border, lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.2), radius: 4, y: 1)
    }
}

extension View {
    func glassPanel() -> some View { modifier(GlassPanel()) }
    func toolbarGlow(active: Bool = false) -> some View { modifier(ToolbarGlow(active: active)) }
    func surfaceCard() -> some View { modifier(SurfaceCard()) }
    func springPress() -> some View {
        self.scaleEffect(1).animation(.spring(response: 0.3, dampingFraction: 0.7), value: UUID())
    }
}

// MARK: - Color Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >> 8) & 0xFF) / 255
        let b = Double(int & 0xFF) / 255
        let a = hex.count == 8 ? Double((int >> 24) & 0xFF) / 255 : 1.0
        self.init(.sRGB, red: r, green: g, blue: b, opacity: a)
    }
}
