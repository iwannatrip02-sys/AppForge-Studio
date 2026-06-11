import SwiftUI
import OSLog

private let logger = Logger(subsystem: "com.appforgestudio", category: "HybridModeView")

// MARK: - Hybrid Layer Panel (inline, works with LayerManager)

struct HybridLayerPanel: View {
    @ObservedObject var layerManager: LayerManager
    @Binding var activeMode: HybridLayerType
    @EnvironmentObject var themeManager: ThemeManager

    private var theme: AppTheme { themeManager.currentTheme }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Capas").font(.headline).foregroundColor(theme.textPrimary)
                Spacer()
                Menu {
                    ForEach(HybridLayerType.allCases, id: \.self) { type in
                        Button(action: {
                            layerManager.addLayer(name: "Capa \(type.displayName) \(layerManager.layers.count + 1)", layerType: type)
                            logger.info("Added \(type.rawValue) layer")
                        }) {
                            Label(type.displayName, systemImage: type.icon)
                        }
                    }
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                        .foregroundColor(.accentColor)
                }
                Button(action: { layerManager.duplicateLayer(layerManager.layers.first { $0.id == layerManager.activeLayerId } ?? layerManager.layers.first ?? ModelLayer(name: "Empty")) }) {
                    Image(systemName: "doc.on.doc")
                        .font(.caption)
                }
                .disabled(layerManager.layers.isEmpty)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider().background(theme.textSecondary.opacity(0.3))

            // Layer list
            if layerManager.layers.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "square.3.layers.3d.down.right").font(.system(size: 32)).foregroundColor(theme.textSecondary.opacity(0.4))
                    Text("Sin capas — toca + para crear una").font(.caption).foregroundColor(theme.textSecondary)
                }.padding(.vertical, 32)
            } else {
                List {
                    ForEach(layerManager.layers) { layer in
                        HybridLayerRow(
                            layer: binding(for: layer),
                            isActive: layerManager.activeLayerId == layer.id,
                            isEditable: layer.layerType == activeMode,
                            onSelect: {
                                layerManager.activeLayerId = layer.id
                                // Auto-switch mode to match layer type
                                activeMode = layer.layerType
                                layerManager.objectWillChange.send()
                            },
                            onToggleVisibility: { layerManager.toggleVisibility(layer) },
                            onDelete: { layerManager.removeLayer(layer) }
                        )
                    }
                    .onMove { indices, newOffset in
                        layerManager.moveLayer(from: indices, to: newOffset)
                    }
                }
                .listStyle(.plain)
                .environment(\.editMode, .constant(.active))
            }
        }
        .background(theme.surface)
        .cornerRadius(12)
        .shadow(radius: 8)
    }

    private func binding(for layer: ModelLayer) -> Binding<ModelLayer> {
        Binding(
            get: { layer },
            set: { newValue in
                if let idx = layerManager.layers.firstIndex(where: { $0.id == layer.id }) {
                    layerManager.layers[idx] = newValue
                }
            }
        )
    }
}

// MARK: - Layer Row

struct HybridLayerRow: View {
    @Binding var layer: ModelLayer
    let isActive: Bool
    let isEditable: Bool
    let onSelect: () -> Void
    let onToggleVisibility: () -> Void
    let onDelete: () -> Void

    @EnvironmentObject var themeManager: ThemeManager
    private var theme: AppTheme { themeManager.currentTheme }

    var body: some View {
        HStack(spacing: 8) {
            // Visibility toggle
            Button(action: onToggleVisibility) {
                Image(systemName: layer.isVisible ? "eye.fill" : "eye.slash")
                    .font(.caption)
                    .foregroundColor(layer.isVisible ? .accentColor : theme.textSecondary)
            }
            .buttonStyle(.plain)

            // Type icon
            Image(systemName: layer.layerType.icon)
                .font(.caption2)
                .foregroundColor(typeColor(layer.layerType))
                .frame(width: 20)

            // Layer name
            VStack(alignment: .leading, spacing: 1) {
                TextField("Nombre", text: $layer.name)
                    .font(.caption)
                    .foregroundColor(isEditable ? theme.textPrimary : theme.textSecondary)
                Text("\(layer.layerType.displayName) · \(layer.operations.count) ops")
                    .font(.caption2)
                    .foregroundColor(theme.textSecondary)
            }

            Spacer()

            // Active indicator
            if isActive {
                Image(systemName: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundColor(.accentColor)
            }

            // Editable badge
            if isEditable {
                Circle()
                    .fill(Color.accentColor)
                    .frame(width: 6, height: 6)
            }
        }
        .padding(.vertical, 3)
        .contentShape(Rectangle())
        .onTapGesture { onSelect() }
        .opacity(layer.isVisible ? 1.0 : 0.5)
        .swipeActions(edge: .trailing) {
            Button(role: .destructive, action: onDelete) {
                Label("Eliminar", systemImage: "trash")
            }
        }
    }

    private func typeColor(_ type: HybridLayerType) -> Color {
        switch type {
        case .cad: return .orange
        case .sculpt: return .blue
        case .paint: return .purple
        }
    }
}

// MARK: - Hybrid Mode View

struct HybridModeView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @ObservedObject var canvasVM: CanvasViewModel
    var renderer: SatinRenderer
    @ObservedObject var toolVM: ToolViewModel
    @ObservedObject var animationVM: AnimationEngine
    @ObservedObject var subdivisionVM: SubdivisionEngine
    @ObservedObject var layerManager: LayerManager

    @State private var activeMode: HybridLayerType = .sculpt
    @State private var showLayers = false
    @State private var showTimeline = false
    @State private var brushSize: Float = 0.05
    @State private var brushOpacity: Float = 0.8

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // Top mode switcher bar
                modeSwitcher
                    .padding(.horizontal)
                    .padding(.vertical, 6)
                    .background(themeManager.currentTheme.surface)

                // 3D Canvas
                ContentView(
                    canvasVM: canvasVM,
                    renderer: renderer,
                    brushEngine: toolVM.brushEngine,
                    isPaintMode: activeMode == .paint
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                // Timeline (animation mode)
                if showTimeline {
                    TimelineView(engine: animationVM)
                        .transition(.move(edge: .bottom))
                        .animation(.easeInOut, value: showTimeline)
                }

                // Bottom toolbar per mode
                bottomToolbar
                    .padding(.horizontal)
                    .padding(.vertical, 4)
                    .background(themeManager.currentTheme.surfaceSecondary)
            }

            // Layer panel overlay (slides from right)
            if showLayers {
                Color.black.opacity(0.3)
                    .edgesIgnoringSafeArea(.all)
                    .onTapGesture { withAnimation(.easeOut(duration: 0.2)) { showLayers = false } }

                HStack {
                    Spacer()
                    HybridLayerPanel(layerManager: layerManager, activeMode: $activeMode)
                        .frame(width: 280)
                        .transition(.move(edge: .trailing))
                }
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: showLayers)
    }

    // MARK: - Mode Switcher

    private var modeSwitcher: some View {
        HStack(spacing: 4) {
            ForEach(HybridLayerType.allCases, id: \.self) { mode in
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        activeMode = mode
                        canvasVM.currentMode = appMode(for: mode)
                        // Activate topmost visible layer of this type
                        if let topLayer = layerManager.activeLayer(for: mode) {
                            layerManager.activeLayerId = topLayer.id
                        }
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: mode.icon)
                            .font(.caption2)
                        Text(mode.displayName)
                            .font(.caption)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(activeMode == mode ? Color.accentColor : themeManager.currentTheme.surfaceSecondary)
                    .foregroundColor(activeMode == mode ? .white : themeManager.currentTheme.textPrimary)
                    .cornerRadius(8)
                }
            }

            Spacer()

            // Layer count badge
            Button(action: { withAnimation(.easeInOut(duration: 0.25)) { showLayers.toggle() } }) {
                HStack(spacing: 3) {
                    Image(systemName: "square.3.layers.3d")
                        .font(.caption)
                    Text("\(layerManager.layers.count)")
                        .font(.caption2.bold())
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(showLayers ? Color.accentColor.opacity(0.3) : themeManager.currentTheme.surfaceSecondary)
                .foregroundColor(themeManager.currentTheme.textPrimary)
                .cornerRadius(6)
            }
        }
    }

    // MARK: - Bottom Toolbar

    @ViewBuilder
    private var bottomToolbar: some View {
        let activeLayer = layerManager.activeLayer(for: activeMode)

        switch activeMode {
        case .cad:
            cadToolbar(activeLayer: activeLayer)
        case .sculpt:
            sculptToolbar(activeLayer: activeLayer)
        case .paint:
            paintToolbar(activeLayer: activeLayer)
        }
    }

    // MARK: - CAD Toolbar

    private func cadToolbar(activeLayer: ModelLayer?) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "gearshape")
                .font(.caption)
                .foregroundColor(.orange)
            Text("CAD").font(.caption).bold()
            if let layer = activeLayer {
                Text("· \(layer.name)")
                    .font(.caption2)
                    .foregroundColor(themeManager.currentTheme.textSecondary)
            } else {
                Text("· sin capa CAD")
                    .font(.caption2)
                    .foregroundColor(themeManager.currentTheme.textSecondary)
            }
            Spacer()

            Button("Extruir") {
                toolVM.selectedTool = .extrude
                executeCADTool(layer: activeLayer, op: .extrude(distance: 10, direction: SIMD3<Double>(0, 1, 0)))
            }
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(themeManager.currentTheme.surface)
            .cornerRadius(6)

            Button("Loop Cut") {
                toolVM.selectedTool = .loopCut
                executeCADTool(layer: activeLayer, op: nil)
            }
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(themeManager.currentTheme.surface)
            .cornerRadius(6)

            Button("Bisel") {
                toolVM.selectedTool = .bevel
                executeCADTool(layer: activeLayer, op: .chamfer(distance: 2))
            }
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(themeManager.currentTheme.surface)
            .cornerRadius(6)

            Button("Booleano") {
                toolVM.selectedTool = .booleanUnion
                executeCADTool(layer: activeLayer, op: nil)
            }
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(themeManager.currentTheme.surface)
            .cornerRadius(6)
        }
    }

    // MARK: - Sculpt Toolbar

    private func sculptToolbar(activeLayer: ModelLayer?) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "hand.draw")
                .font(.caption)
                .foregroundColor(.blue)
            Text("Esculpir").font(.caption).bold()
            if let layer = activeLayer {
                Text("· \(layer.name)")
                    .font(.caption2)
                    .foregroundColor(themeManager.currentTheme.textSecondary)
            } else {
                Text("· sin capa Sculpt")
                    .font(.caption2)
                    .foregroundColor(themeManager.currentTheme.textSecondary)
            }
            Spacer()

            // Brush size slider
            Slider(value: $brushSize, in: 0.005...0.3)
                .frame(width: 60)
            Text(String(format: "%.0f%%", brushSize * 100))
                .font(.caption2)
                .foregroundColor(themeManager.currentTheme.textSecondary)

            // Deformer presets — sculpt runs via SculptEngine touch pipeline, not ToolViewModel
            Menu {
                Button("Grab") { }
                Button("Inflate") { }
                Button("Smooth") { }
                Button("Flatten") { }
                Button("Pinch") { }
            } label: {
                Image(systemName: "scribble.variable")
                    .font(.caption)
            }

            Button("Subdividir") {
                guard let model = canvasVM.scene.models.first else { return }
                let mesh = model.meshes.first ?? Mesh(vertices: [], indices: [])
                let subdivided = subdivisionVM.subdivide(mesh, levels: 1)
                let newModel = Model(name: model.name + "_subd", meshes: [subdivided])
                canvasVM.scene.addModel(newModel)
                canvasVM.objectWillChange.send()
                if let layerId = activeLayer?.id {
                    layerManager.addOperation(.subdivision(levels: 1), to: layerId)
                }
            }
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(themeManager.currentTheme.surface)
            .cornerRadius(6)

            Button("Remesh") {
                guard let model = canvasVM.scene.models.first, let mesh = model.meshes.first else { return }
                _ = SDFEngine()
                canvasVM.objectWillChange.send()
            }
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(themeManager.currentTheme.surface)
            .cornerRadius(6)
        }
    }

    // MARK: - Paint Toolbar

    private func paintToolbar(activeLayer: ModelLayer?) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "paintpalette")
                .font(.caption)
                .foregroundColor(.purple)
            Text("Pintar").font(.caption).bold()
            if let layer = activeLayer {
                Text("· \(layer.name)")
                    .font(.caption2)
                    .foregroundColor(themeManager.currentTheme.textSecondary)
            } else {
                Text("· sin capa Paint")
                    .font(.caption2)
                    .foregroundColor(themeManager.currentTheme.textSecondary)
            }
            Spacer()

            ColorPicker("", selection: Binding(
                get: { Color(red: 0, green: 0.5, blue: 1) },
                set: { _ in }
            ))
            .labelsHidden()
            .scaleEffect(0.8)

            Slider(value: $brushSize, in: 0.005...0.2)
                .frame(width: 50)
            Slider(value: $brushOpacity, in: 0...1)
                .frame(width: 40)

            Button("Rellenar") {
                // Paint fill runs via BrushEngine touch pipeline
            }
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(themeManager.currentTheme.surface)
            .cornerRadius(6)
        }
    }

    // MARK: - Helpers

    private func appMode(for layerType: HybridLayerType) -> CanvasViewModel.AppMode {
        switch layerType {
        case .cad: return .cad
        case .sculpt: return .sculpt
        case .paint: return .hybrid // paint doesn't have its own AppMode; hybrid covers it
        }
    }

    /// Execute a CAD tool on the active layer's mesh, then record the operation.
    /// Adapts ToolViewModel.executeTool(mesh:) to CanvasViewModel.currentMesh.
    private func executeCADTool(layer: ModelLayer?, op: LayerOperation?) {
        var mesh = canvasVM.currentMesh
        toolVM.executeTool(mesh: &mesh)
        canvasVM.currentMesh = mesh
        if let layerId = layer?.id, let operation = op {
            layerManager.addOperation(operation, to: layerId)
        }
    }
}
