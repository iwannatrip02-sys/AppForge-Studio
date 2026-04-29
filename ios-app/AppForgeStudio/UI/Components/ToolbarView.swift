import SwiftUI

struct ToolbarView: View {
    @ObservedObject var toolVM: ToolViewModel
    @Binding var scene: Scene3D
    
    var body: some View {
        HStack(spacing: 8) {
            if toolVM.currentMode == .CAD || toolVM.currentMode == .Hybrid {
                Toggle("Snap", isOn: $toolVM.snapEnabled)
                    .toggleStyle(.button)
                    .font(.caption)
                Picker("Space", selection: $toolVM.transformSpace) {
                    Text("Local").tag("local")
                    Text("World").tag("world")
                }
                .pickerStyle(.segmented)
                .frame(width: 120)
            }
            if toolVM.currentMode == .Sculpt || toolVM.currentMode == .Paint {
                ForEach(toolVM.brushPresets, id: \.self["name"] as? String ?? "") { preset in
                    Button(preset["name"] as? String ?? "") {
                        toolVM.selectPreset(preset)
                    }
                    .font(.caption2)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.gray.opacity(0.3))
                    .cornerRadius(6)
                }
            }
            Spacer()
        }
        .padding(.horizontal)
        .frame(height: 40)
    }
}