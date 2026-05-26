import SwiftUI
import OSLog

private let logger = Logger(subsystem: "com.appforgestudio", category: "AppThemeEnvironment")
struct AppThemeKey: EnvironmentKey {
    static let defaultValue: AppTheme = .dark
}

extension EnvironmentValues {
    var appTheme: AppTheme {
        get { self[AppThemeKey.self] }
        set { self[AppThemeKey.self] = newValue }
    }
}
