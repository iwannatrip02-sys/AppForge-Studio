import SwiftUI

struct ModeSelectorView: View {
    @Binding var selectedMode: AppState.AppMode
    @ObservedObject var themeManager: ThemeManager
    @State private var showThemePicker = false

    var body: some View {
        HStack(spacing: 0) {
            ForEach(AppState.AppMode.allCases, id: \.self) { mode in
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedMode = mode
                    }
                }) {
                    Text(mode.rawValue)
                        .font(.caption)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(selectedMode == mode ? Color.accentColor : themeManager.currentTheme.surfaceSecondary)
                        .foregroundColor(themeManager.currentTheme.textPrimary)
                }
            }

            Divider()
                .frame(height: 20)
                .padding(.horizontal, 6)

            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showThemePicker.toggle()
                }
            }) {
                Image(systemName: themeManager.themeMode.icon)
                    .font(.caption)
                    .foregroundColor(themeManager.currentTheme.textPrimary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(themeManager.currentTheme.surfaceSecondary)
            }
            .popover(isPresented: $showThemePicker, arrowEdge: .bottom) {
                themePickerPopover
            }
        }
        .background(themeManager.currentTheme.surface)
        .cornerRadius(8)
    }

    private var themePickerPopover: some View {
        VStack(spacing: 0) {
            ForEach(AppThemeMode.allCases, id: \.self) { mode in
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        themeManager.themeMode = mode
                        showThemePicker = false
                    }
                }) {
                    HStack(spacing: 12) {
                        Image(systemName: mode.icon)
                            .frame(width: 20)
                        Text(mode.rawValue)
                        Spacer()
                        if themeManager.themeMode == mode {
                            Image(systemName: "checkmark")
                                .foregroundColor(.accentColor)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .foregroundColor(themeManager.currentTheme.textPrimary)
                }
                if mode != AppThemeMode.allCases.last {
                    Divider().padding(.leading, 48)
                }
            }
        }
        .padding(.vertical, 4)
        .frame(width: 200)
    }
}
