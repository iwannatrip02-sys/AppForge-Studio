import SwiftUI

extension Color {
    init(hex: UInt) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8) & 0xFF) / 255.0,
            blue: Double(hex & 0xFF) / 255.0
        )
    }
}

struct AppTheme {
    var background: Color
    var surface: Color
    var surfaceSecondary: Color
    var textPrimary: Color
    var textSecondary: Color
    var accent: Color
    var border: Color
    var destructive: Color
    var success: Color
    var metalBackground: UIColor

    var titleFont: Font { .system(size: 20, weight: .bold, design: .rounded) }
    var bodyFont: Font { .system(size: 14, weight: .regular) }
    var captionFont: Font { .system(size: 11, weight: .medium) }
    var cornerRadiusSmall: CGFloat { 8 }
    var cornerRadiusMedium: CGFloat { 12 }
    var cornerRadiusLarge: CGFloat { 20 }
    var elevation: CGFloat { 2 }
    var iconSizeSmall: CGFloat { 16 }
    var iconSizeMedium: CGFloat { 22 }
    var iconSizeLarge: CGFloat { 28 }

    static let dark = AppTheme(
        background: Color(hex: 0x0D0D0D),
        surface: Color(hex: 0x1C1C1E),
        surfaceSecondary: Color(hex: 0x2C2C2E),
        textPrimary: Color(hex: 0xF2F2F7),
        textSecondary: Color(hex: 0x8E8E93),
        accent: .blue,
        border: Color(hex: 0x38383A),
        destructive: .red,
        success: .green,
        metalBackground: UIColor.darkGray
    )

    static let light = AppTheme(
        background: Color(hex: 0xF2F2F7),
        surface: Color(hex: 0xFFFFFF),
        surfaceSecondary: Color(hex: 0xE5E5EA),
        textPrimary: Color(hex: 0x1C1C1E),
        textSecondary: Color(hex: 0x636366),
        accent: .blue,
        border: Color(hex: 0xC6C6C8),
        destructive: .red,
        success: .green,
        metalBackground: UIColor.lightGray
    )

    func color(for scheme: ColorScheme) -> AppTheme {
        switch scheme {
        case .dark: return .dark
        case .light: return .light
        @unknown default: return .dark
        }
    }

    static func theme(for scheme: ColorScheme) -> AppTheme {
        switch scheme {
        case .dark: return .dark
        case .light: return .light
        @unknown default: return .dark
        }
    }
}
