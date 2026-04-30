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
                Button(action: { toolVM.resetCamera() }) {
                    Label("Reset View", systemImage: "camera.viewfinder")
                        .font(.caption2)
                }
                .buttonStyle(.bordered)
            }
            if toolVM.currentMode == .Sculpt || toolVM.currentMode == .Paint {
                ForEach(toolVM.brushPresets.map { $0["name"] as? String ?? "" }.filter { !$0.isEmpty }, id: \.self) { name in
                    Button(name) {
                        toolVM.selectPreset(["name": name])
                    }
                    .font(.caption2)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.gray.opacity(0.3))
                    .cornerRadius(6)
                }
            }
            if toolVM.currentMode == .Animation {
                Toggle(isOn: Binding(
                    get: { toolVM.animationLoop },
                    set: { toolVM.animationLoop = $0 }
                )) {
                    Image(systemName: "repeat")
                        .font(.caption)
                }
                .toggleStyle(.button)
                Stepper(value: Binding(
                    get: { toolVM.animationSpeed },
                    set: { toolVM.animationSpeed = $0 }
                ), in: 0.5...3.0, step: 0.5) {
                    Text(String(format: "%.1fx", toolVM.animationSpeed))
                        .font(.caption2)
                        .frame(width: 36)
                }
                .frame(width: 100)
                Button(action: { toolVM.addKeyframe() }) {
                    Image(systemName: "plus.circle")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
            }
            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 6)
        .background(Color.black.opacity(0.4))
        .cornerRadius(10)
        .frame(height: 44)
    }
}