import SwiftUI
import UIKit

struct ToolbarView: View {
    @ObservedObject var toolVM: ToolViewModel
    @Binding var scene: Scene3D
    @EnvironmentObject var themeManager: ThemeManager

    private var theme: AppTheme { themeManager.currentTheme }

    private func triggerHaptic(style: UIImpactFeedbackGenerator.FeedbackStyle = .light) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.prepare()
        generator.impactOccurred()
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                if toolVM.currentMode == .CAD || toolVM.currentMode == .Hybrid {
                    toolbarButton(icon: "magnet", label: "Snap", isActive: toolVM.snapEnabled) {
                        triggerHaptic()
                        toolVM.snapEnabled.toggle()
                    }
                    .keyboardShortcut("s", modifiers: [.command])
                    .help("Snap to grid")

                    ToolbarSpacePicker(transformSpace: $toolVM.transformSpace)

                    toolbarButton(icon: "arrow.counterclockwise", label: "Reset") {
                        triggerHaptic()
                        toolVM.resetCamera()
                    }
                    .keyboardShortcut("r", modifiers: [.command])
                    .help("Reset camera view")

                    Divider().frame(height: 24).foregroundColor(theme.border)
                }

                if toolVM.currentMode == .Sculpt || toolVM.currentMode == .Paint {
                    ForEach(toolVM.brushPresets.map { $0["name"] as? String ?? "" }.filter { !$0.isEmpty }, id: \.self) { name in
                        toolbarButton(icon: "paintbrush.fill", label: name) {
                            triggerHaptic()
                            toolVM.selectPreset(["name": name])
                        }
                        .help("Brush: " + name)
                    }
                    Divider().frame(height: 24).foregroundColor(theme.border)
                }

                if toolVM.currentMode == .Animation {
                    toolbarButton(icon: "repeat", label: "Loop", isActive: false) {
                        triggerHaptic()
                    }
                        .help("Animation loop toggle")
                }

                if toolVM.hasSelection {
                    toolbarButton(icon: "trash", label: "Delete") {
                        triggerHaptic(style: .heavy)
                        toolVM.deleteSelected()
                    }
                    .keyboardShortcut(.delete, modifiers: [])
                    .foregroundColor(theme.destructive)
                    .help("Delete selected object")
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(themeManager.isDarkMode ? Color.black.opacity(0.6) : theme.surface)
            .cornerRadius(12)
        }
    }

    @ViewBuilder
    private func toolbarButton(icon: String, label: String, isActive: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .frame(width: 28, height: 28)
                    .background(isActive ? Color.blue.opacity(0.3) : Color.clear)
                    .cornerRadius(8)
                Text(label)
                    .font(.system(size: 7))
                    .lineLimit(1)
            }
            .foregroundColor(isActive ? .blue : theme.textPrimary)
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
            .background(isActive ? Color.blue.opacity(0.1) : Color.clear)
            .cornerRadius(10)
        }
        .buttonStyle(.plain)
    }
}