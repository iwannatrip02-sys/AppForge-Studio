import SwiftUI

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

    static let dark = AppTheme(
        background: Color.black,
        surface: Color.black.opacity(0.8),
        surfaceSecondary: Color.gray.opacity(0.15),
        textPrimary: Color.white,
        textSecondary: Color.gray,
        accent: Color.accentColor,
        border: Color.gray.opacity(0.3),
        destructive: Color.red,
        success: Color.green,
        metalBackground: .darkGray
    )

    static let light = AppTheme(
        background: Color(.systemBackground),
        surface: Color(.systemGray6),
        surfaceSecondary: Color(.systemGray5),
        textPrimary: Color.primary,
        textSecondary: Color.secondary,
        accent: Color.accentColor,
        border: Color(.separator),
        destructive: Color.red,
        success: Color.green,
        metalBackground: .lightGray
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
