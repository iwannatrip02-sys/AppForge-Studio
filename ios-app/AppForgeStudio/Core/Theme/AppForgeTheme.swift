import SwiftUI

// MARK: - Shapr3D-inspired Design System

/// Professional dark theme with blue accent — Shapr3D aesthetic.
struct AppForgeTheme {
    // Surfaces
    static let background    = Color(hex: "0D1117")
    static let surface       = Color(hex: "161B22")
    static let surfaceRaised = Color(hex: "1C2333")
    static let surfaceOverlay = Color(hex: "21262D")
    
    // Accent
    static let accent        = Color(hex: "3B82F6")  // Blue
    static let accentDim     = Color(hex: "2563EB")
    static let accentGlow    = Color(hex: "60A5FA")
    
    // Success / Warning / Error
    static let success       = Color(hex: "22C55E")
    static let warning       = Color(hex: "F59E0B")
    static let error         = Color(hex: "EF4444")
    
    // Text
    static let textPrimary   = Color(hex: "E6EDF3")
    static let textSecondary = Color(hex: "8B949E")
    static let textTertiary  = Color(hex: "484F58")
    
    // Borders
    static let border        = Color(hex: "30363D")
    static let borderLight   = Color(hex: "21262D")
    
    // Axis colors
    static let axisX = Color(hex: "EF4444")
    static let axisY = Color(hex: "22C55E")
    static let axisZ = Color(hex: "3B82F6")
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Professional Button Styles

struct ToolbarButtonStyle: ButtonStyle {
    var isActive: Bool = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: isActive ? .semibold : .regular))
            .foregroundColor(isActive ? .white : AppForgeTheme.textSecondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isActive ? AppForgeTheme.accent : AppForgeTheme.surfaceRaised)
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isActive ? AppForgeTheme.accent : AppForgeTheme.border, lineWidth: 1)
            )
            .opacity(configuration.isPressed ? 0.7 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct ModeButtonStyle: ButtonStyle {
    var isActive: Bool = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 11, weight: isActive ? .semibold : .regular))
            .foregroundColor(isActive ? .white : AppForgeTheme.textSecondary)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                isActive
                    ? AppForgeTheme.accent.opacity(0.15)
                    : Color.clear
            )
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isActive ? AppForgeTheme.accent.opacity(0.4) : Color.clear, lineWidth: 1)
            )
            .contentShape(Rectangle())
    }
}

struct ToolChipStyle: ButtonStyle {
    var isActive: Bool = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 10.5))
            .foregroundColor(isActive ? .white : AppForgeTheme.textSecondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(isActive ? AppForgeTheme.accent : AppForgeTheme.surfaceOverlay)
            .cornerRadius(4)
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}
