import SwiftUI
import UIKit
import OSLog

private let logger = Logger(subsystem: "com.appforgestudio", category: "ToolbarView")
struct ToolbarView: View {
    @ObservedObject var toolVM: ToolViewModel
    @Binding var scene: Scene3D
    @EnvironmentObject var themeManager: ThemeManager

    private var theme: AppTheme { themeManager.currentTheme }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                if toolVM.currentMode == .CAD || toolVM.currentMode == .Hybrid {
                    toolbarButton(icon: "magnet", label: "Snap", isActive: toolVM.snapEnabled) {
                        HapticService.shared.light()
                        toolVM.snapEnabled.toggle()
                    }
                    .keyboardShortcut("s", modifiers: [.command])
                    .help("Snap to grid")
                    .accessibilityLabel("Snap to grid")
                    .dynamicTypeSize(...DynamicTypeSize.xLarge)

                    ToolbarSpacePicker(transformSpace: $toolVM.transformSpace)

                    toolbarButton(icon: "arrow.counterclockwise", label: "Reset") {
                        HapticService.shared.light()
                        toolVM.resetCamera()
                    }
                    .keyboardShortcut("r", modifiers: [.command])
                    .help("Reset camera view")
                    .accessibilityLabel("Reset camera")
                    .dynamicTypeSize(...DynamicTypeSize.xLarge)

                    Divider().frame(height: 24).foregroundColor(theme.border)
                }

                if toolVM.currentMode == .Sculpt || toolVM.currentMode == .Paint {
                    ForEach(toolVM.brushPresets.map { $0["name"] as? String ?? "" }.filter { !$0.isEmpty }, id: \.self) { name in
                        toolbarButton(icon: "paintbrush.fill", label: name) {
                            HapticService.shared.light()
                            toolVM.selectPreset(["name": name])
                        }
                        .help("Brush: " + name)
                        .accessibilityLabel("Pincel \(name)")
                        .dynamicTypeSize(...DynamicTypeSize.xLarge)
                    }
                    Divider().frame(height: 24).foregroundColor(theme.border)
                }

                if toolVM.currentMode == .Animation {
                    toolbarButton(icon: "repeat", label: "Loop", isActive: false) {
                        HapticService.shared.light()
                    }
                        .help("Animation loop toggle")
                        .accessibilityLabel("Loop de animacion")
                        .dynamicTypeSize(...DynamicTypeSize.xLarge)
                }

                if toolVM.hasSelection {
                    toolbarButton(icon: "trash", label: "Delete") {
                        HapticService.shared.heavy()
                        toolVM.deleteSelected()
                    }
                    .keyboardShortcut(.delete, modifiers: [])
                    .foregroundColor(theme.destructive)
                    .help("Delete selected object")
                    .accessibilityLabel("Eliminar seleccion")
                    .dynamicTypeSize(...DynamicTypeSize.xLarge)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(theme.surface)
            .cornerRadius(theme.cornerRadiusMedium)
            .shadow(color: .black.opacity(0.15), radius: theme.elevation * 2, y: 2)
        }
        .padding(.horizontal, 4)
    }

    @ViewBuilder
    private func toolbarButton(icon: String, label: String, isActive: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Image(systemName: icon)
                    .font(.system(size: theme.iconSizeSmall))
                    .frame(width: theme.iconSizeMedium, height: theme.iconSizeMedium)
                    .background(isActive ? theme.accent.opacity(0.25) : Color.clear)
                    .cornerRadius(theme.cornerRadiusSmall)
                Text(label)
                    .font(theme.captionFont)
                    .lineLimit(1)
            }
            .foregroundColor(isActive ? theme.accent : theme.textPrimary)
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
            .background(isActive ? theme.accent.opacity(0.08) : Color.clear)
            .cornerRadius(theme.cornerRadiusSmall)
        }
        .buttonStyle(.plain)
    }
}
