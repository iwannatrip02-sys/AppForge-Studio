import SwiftUI
import Combine
import OSLog

private let logger = Logger(subsystem: "com.appforgestudio", category: "ThemeManager")
enum AppThemeMode: String, CaseIterable {
    case system = "Sistema"
    case dark = "Oscuro"
    case light = "Claro"

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .dark: return .dark
        case .light: return .light
        }
    }

    var icon: String {
        switch self {
        case .system: return "circle.lefthalf.filled"
        case .dark: return "moon.fill"
        case .light: return "sun.max.fill"
        }
    }
}

@MainActor
class ThemeManager: ObservableObject {
    @Published var themeMode: AppThemeMode {
        didSet {
            UserDefaults.standard.set(themeMode.rawValue, forKey: "appThemeMode")
        }
    }

    @Published var currentTheme: AppTheme = .dark
    @Published var isDarkMode: Bool = true

    var preferredColorScheme: ColorScheme? {
        themeMode.colorScheme
    }

    func updateForColorScheme(_ scheme: ColorScheme) {
        let isDark: Bool
        switch themeMode {
        case .system:
            isDark = scheme == .dark
        case .dark:
            isDark = true
        case .light:
            isDark = false
        }
        if isDarkMode != isDark {
            isDarkMode = isDark
            currentTheme = isDark ? .dark : .light
        }
    }

    init() {
        if let saved = UserDefaults.standard.string(forKey: "appThemeMode"),
           let mode = AppThemeMode(rawValue: saved) {
            self.themeMode = mode
        } else {
            self.themeMode = .dark
        }
        switch themeMode {
        case .dark:
            self.currentTheme = .dark
            self.isDarkMode = true
        case .light:
            self.currentTheme = .light
            self.isDarkMode = false
        case .system:
            self.currentTheme = .dark
            self.isDarkMode = true
        }
    }
}
