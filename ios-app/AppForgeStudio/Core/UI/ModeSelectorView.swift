import SwiftUI
import OSLog

private let logger = Logger(subsystem: "com.appforgestudio", category: "ModeSelectorView")
struct ModeSelectorView: View {
    @Binding var selectedMode: AppState.AppMode
    @ObservedObject var themeManager: ThemeManager
    @State private var showThemePicker = false

    private var theme: AppTheme { themeManager.currentTheme }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(AppState.AppMode.allCases, id: \.self) { mode in
                Button(action: {
                    HapticService.shared.medium()
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedMode = mode
                    }
                }) {
                    Text(mode.rawValue)
                        .font(theme.captionFont)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(selectedMode == mode ? theme.accent : theme.surfaceSecondary)
                        .foregroundColor(theme.textPrimary)
                        .cornerRadius(theme.cornerRadiusLarge)
                }
                .accessibilityLabel("Modo \(mode.rawValue)")
                .dynamicTypeSize(...DynamicTypeSize.xLarge)
            }

            Divider()
                .frame(height: 20)
                .padding(.horizontal, 6)

            Button(action: {
                HapticService.shared.selection()
                withAnimation(.easeInOut(duration: 0.2)) {
                    showThemePicker.toggle()
                }
            }) {
                Image(systemName: themeManager.themeMode.icon)
                    .font(.system(size: theme.iconSizeSmall))
                    .foregroundColor(theme.textPrimary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(theme.surfaceSecondary)
                    .cornerRadius(theme.cornerRadiusSmall)
            }
            .accessibilityLabel("Cambiar tema")
            .dynamicTypeSize(...DynamicTypeSize.xLarge)
            .popover(isPresented: $showThemePicker, arrowEdge: .bottom) {
                themePickerPopover
            }
        }
        .background(theme.surface)
        .cornerRadius(theme.cornerRadiusMedium)
        .shadow(color: .black.opacity(0.1), radius: theme.elevation, y: 1)
        .dynamicTypeSize(...DynamicTypeSize.xLarge)
    }

    private var themePickerPopover: some View {
        VStack(spacing: 0) {
            ForEach(AppThemeMode.allCases, id: \.self) { mode in
                Button(action: {
                    HapticService.shared.selection()
                    withAnimation(.easeInOut(duration: 0.25)) {
                        themeManager.themeMode = mode
                        showThemePicker = false
                    }
                }) {
                    HStack(spacing: 12) {
                        Image(systemName: mode.icon)
                            .frame(width: theme.iconSizeSmall)
                        Text(mode.rawValue)
                            .font(theme.captionFont)
                        Spacer()
                        if themeManager.themeMode == mode {
                            Image(systemName: "checkmark")
                                .foregroundColor(.accentColor)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .foregroundColor(theme.textPrimary)
                }
                .accessibilityLabel("Tema \(mode.rawValue)")
                if mode != AppThemeMode.allCases.last {
                    Divider().padding(.leading, 48)
                }
            }
        }
        .padding(.vertical, 4)
        .frame(width: 200)
        .dynamicTypeSize(...DynamicTypeSize.xLarge)
    }
}
