import SwiftUI
import Metal
import Satin
import OSLog

private let logger = Logger(subsystem: "com.appforgestudio", category: "AppForgeStudioApp")

@main
struct AppForgeStudioApp: App {
    @StateObject private var appState = AppState()
    @State private var showOnboarding = !UserDefaults.standard.bool(forKey: "onboardingComplete")
    
    var body: some Scene {
        WindowGroup {
            if showOnboarding {
                AppForgeOnboarding(showOnboarding: $showOnboarding)
                    .preferredColorScheme(.dark)
            } else if appState.isLoading {
                AppForgeLoading(isLoading: $appState.isLoading)
                    .preferredColorScheme(.dark)
            } else {
                AppForgeWorkspace(appState: appState)
                    .preferredColorScheme(.dark)
            }
        }
    }
}

// MARK: - Onboarding

struct AppForgeOnboarding: View {
    @Binding var showOnboarding: Bool
    @State private var page = 0
    
    var body: some View {
        ZStack {
            AppForgeTheme.background.ignoresSafeArea()
            VStack(spacing: 24) {
                Spacer()
                Image(systemName: ["cube.transparent", "scribble.variable", "paintbrush.pointed", "gearshape.2"][page])
                    .font(.system(size: 48))
                    .foregroundColor(AppForgeTheme.accent)
                Text(["Modelado CAD profesional", "Escultura orgánica libre", "Pintura PBR en tiempo real", "Exporta a cualquier formato"][page])
                    .font(.title2).bold()
                    .foregroundColor(AppForgeTheme.textPrimary)
                Spacer()
                Button(page < 3 ? "Continuar" : "Comenzar") {
                    if page < 3 { withAnimation { page += 1 } }
                    else { UserDefaults.standard.set(true, forKey: "onboardingComplete"); showOnboarding = false }
                }
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal, 48).padding(.vertical, 14)
                .background(AppForgeTheme.accent)
                .cornerRadius(12)
                .padding(.bottom, 60)
            }
        }
    }
}

// MARK: - Loading

struct AppForgeLoading: View {
    @Binding var isLoading: Bool
    var body: some View {
        ZStack {
            AppForgeTheme.background.ignoresSafeArea()
            VStack(spacing: 16) {
                ProgressView().scaleEffect(1.5).tint(AppForgeTheme.accent)
                Text("Inicializando kernel CAD...").font(.caption).foregroundColor(AppForgeTheme.textSecondary)
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                    withAnimation(.easeInOut(duration: 0.5)) { isLoading = false }
                }
            }
        }
    }
}

// MARK: - Main Workspace (Shapr3D layout)

struct AppForgeWorkspace: View {
    @ObservedObject var appState: AppState
    @State private var showLeftPanel = true
    @State private var showRightPanel = true
    @State private var activeTool: CADToolType = .select
    
    var body: some View {
        HStack(spacing: 0) {
            // LEFT TOOLBAR — Vertical, icon-only, Shapr3D style
            if showLeftPanel {
                AppForgeLeftToolbar(activeTool: $activeTool, appState: appState)
                    .transition(.move(edge: .leading))
            }
            
            // CENTER VIEWPORT — Takes all available space
            ZStack {
                AppForgeTheme.background
                
                // 3D Viewport
                AppForgeViewport(appState: appState)
                
                // Floating tool palette (bottom-left, overlaid)
                VStack {
                    Spacer()
                    HStack {
                        AppForgeFloatingTools(activeTool: $activeTool, appState: appState)
                        Spacer()
                        // ViewCube mini
                        AppForgeViewCube()
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 60)
                }
                
                // Top status bar
                VStack {
                    AppForgeStatusBar(appState: appState)
                    Spacer()
                }
            }
            
            // RIGHT PANEL — Properties + Parameters
            if showRightPanel && activeTool != .select {
                AppForgeRightPanel(activeTool: $activeTool, appState: appState)
                    .transition(.move(edge: .trailing))
            }
        }
        .background(AppForgeTheme.background)
        .overlay(alignment: .bottom) {
            // Bottom mode bar
            AppForgeModeBar(selectedMode: $appState.selectedMode, showLeftPanel: $showLeftPanel, showRightPanel: $showRightPanel)
        }
        .animation(.easeInOut(duration: 0.25), value: showLeftPanel)
        .animation(.easeInOut(duration: 0.25), value: showRightPanel)
        .animation(.easeInOut(duration: 0.25), value: appState.selectedMode)
        .animation(.easeInOut(duration: 0.2), value: activeTool)
    }
}

// MARK: - Left Toolbar (Shapr3D-style vertical icon bar)

enum CADToolType: String, CaseIterable {
    case select, sketch, extrude, revolve, fillet, chamfer, shell,
         loft, sweep, boolean, measure, transform
    var icon: String {
        switch self {
        case .select: "arrow.up.left.and.arrow.down.right"
        case .sketch: "pencil.and.outline"
        case .extrude: "arrow.up.to.line"
        case .revolve: "arrow.triangle.2.circlepath"
        case .fillet: "circle.lefthalf.filled.righthalf.striped.horizontal"
        case .chamfer: "triangle.lefthalf.filled"
        case .shell: "square.dotted"
        case .loft: "rectangle.3.group"
        case .sweep: "point.topleft.down.to.point.bottomright.curvepath"
        case .boolean: "circle.grid.cross"
        case .measure: "ruler"
        case .transform: "arrow.up.and.down.and.arrow.left.and.right"
        }
    }
    var label: String { rawValue.capitalized }
}

struct AppForgeLeftToolbar: View {
    @Binding var activeTool: CADToolType
    @ObservedObject var appState: AppState
    
    var body: some View {
        VStack(spacing: 2) {
            // App logo
            Image(systemName: "cube.transparent.fill")
                .font(.system(size: 18))
                .foregroundColor(AppForgeTheme.accent)
                .padding(.bottom, 12)
            
            Divider().background(AppForgeTheme.border).padding(.horizontal, 8)
            
            // Tool buttons
            ForEach(CADToolType.allCases, id: \.self) { tool in
                Button(action: { activeTool = tool }) {
                    Image(systemName: tool.icon)
                        .font(.system(size: 16))
                        .frame(width: 40, height: 40)
                        .foregroundColor(activeTool == tool ? .white : AppForgeTheme.textSecondary)
                        .background(activeTool == tool ? AppForgeTheme.accent.opacity(0.2) : Color.clear)
                        .cornerRadius(8)
                }
                .help(tool.label)
            }
            
            Spacer()
            
            Divider().background(AppForgeTheme.border).padding(.horizontal, 8)
            
            // Utility buttons
            Button(action: {}) {
                Image(systemName: "square.and.arrow.down")
                    .font(.system(size: 14))
                    .frame(width: 40, height: 40)
                    .foregroundColor(AppForgeTheme.textSecondary)
            }
            Button(action: { appState.showExport.toggle() }) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 14))
                    .frame(width: 40, height: 40)
                    .foregroundColor(AppForgeTheme.textSecondary)
            }
        }
        .padding(.vertical, 12)
        .frame(width: 52)
        .background(AppForgeTheme.surface)
        .overlay(alignment: .trailing) {
            Rectangle().fill(AppForgeTheme.border).frame(width: 1)
        }
    }
}

// MARK: - Viewport

struct AppForgeViewport: View {
    @ObservedObject var appState: AppState
    
    var body: some View {
        ContentView(
            canvasVM: appState.canvasVM,
            renderer: appState.satinRenderer,
            brushEngine: appState.toolVM.brushEngine,
            isPaintMode: false
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Floating Tools (bottom-left overlay)

struct AppForgeFloatingTools: View {
    @Binding var activeTool: CADToolType
    @ObservedObject var appState: AppState
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(activeTool.label)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(AppForgeTheme.textPrimary)
                .padding(.horizontal, 10).padding(.top, 8)
            
            switch activeTool {
            case .extrude:
                VStack(alignment: .leading, spacing: 4) {
                    ParamRow(label: "Distance", value: "25.0 mm")
                    ParamRow(label: "Direction", value: "Y+")
                    ParamRow(label: "Taper", value: "0°")
                }.padding(.horizontal, 10).padding(.bottom, 8)
            case .fillet:
                VStack(alignment: .leading, spacing: 4) {
                    ParamRow(label: "Radius", value: "2.5 mm")
                    ParamRow(label: "Type", value: "Constant")
                }.padding(.horizontal, 10).padding(.bottom, 8)
            case .boolean:
                HStack(spacing: 4) {
                    AppForgeToolChip("A", active: true)
                    AppForgeToolChip("B")
                    AppForgeToolChip("Union", active: false, color: .green)
                    AppForgeToolChip("Sub")
                    AppForgeToolChip("Int")
                }.padding(.horizontal, 10).padding(.bottom, 8)
            default:
                EmptyView()
            }
        }
        .background(AppForgeTheme.surfaceRaised.opacity(0.95))
        .cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(AppForgeTheme.border, lineWidth: 1))
        .shadow(color: .black.opacity(0.4), radius: 12, y: 4)
    }
}

struct AppForgeToolChip: View {
    let label: String
    var active = false
    var color: Color? = nil
    init(_ label: String, active: Bool = false, color: Color? = nil) {
        self.label = label; self.active = active; self.color = color
    }
    var body: some View {
        Text(label)
            .font(.system(size: 10, weight: active ? .bold : .regular))
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(active ? (color ?? AppForgeTheme.accent) : AppForgeTheme.surfaceOverlay)
            .foregroundColor(active ? .white : AppForgeTheme.textSecondary)
            .cornerRadius(4)
    }
}

struct ParamRow: View {
    let label: String; let value: String
    var body: some View {
        HStack {
            Text(label).font(.system(size: 10)).foregroundColor(AppForgeTheme.textTertiary)
            Spacer()
            Text(value).font(.system(size: 11, weight: .medium)).foregroundColor(AppForgeTheme.textPrimary)
        }
    }
}

// MARK: - ViewCube

struct AppForgeViewCube: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8).fill(AppForgeTheme.surfaceRaised.opacity(0.8))
                .frame(width: 72, height: 72)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppForgeTheme.border, lineWidth: 1))
            
            VStack(spacing: 0) {
                Button(action: {}) {
                    Image(systemName: "arrow.up").font(.system(size: 10)).foregroundColor(AppForgeTheme.textSecondary)
                }.frame(height: 18)
                HStack(spacing: 0) {
                    Button(action: {}) {
                        Image(systemName: "arrow.left").font(.system(size: 10)).foregroundColor(AppForgeTheme.textSecondary)
                    }.frame(width: 18)
                    Image(systemName: "cube").font(.system(size: 14)).foregroundColor(AppForgeTheme.accent)
                    Button(action: {}) {
                        Image(systemName: "arrow.right").font(.system(size: 10)).foregroundColor(AppForgeTheme.textSecondary)
                    }.frame(width: 18)
                }.frame(height: 18)
                Button(action: {}) {
                    Image(systemName: "arrow.down").font(.system(size: 10)).foregroundColor(AppForgeTheme.textSecondary)
                }.frame(height: 18)
            }
        }
        .frame(width: 72, height: 72)
    }
}

// MARK: - Status Bar

struct AppForgeStatusBar: View {
    @ObservedObject var appState: AppState
    
    var body: some View {
        HStack {
            Text("AppForge Studio")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(AppForgeTheme.textPrimary)
            Text("· Untitled")
                .font(.system(size: 12))
                .foregroundColor(AppForgeTheme.textTertiary)
            Spacer()
            HStack(spacing: 12) {
                StatusBadge("OCCT 8.0")
                StatusBadge("60 FPS")
                StatusBadge("PBR")
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(AppForgeTheme.surface.opacity(0.9))
    }
}

struct StatusBadge: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text)
            .font(.system(size: 9, weight: .medium))
            .foregroundColor(AppForgeTheme.textTertiary)
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(AppForgeTheme.surfaceRaised)
            .cornerRadius(3)
    }
}

// MARK: - Right Panel (Properties)

struct AppForgeRightPanel: View {
    @Binding var activeTool: CADToolType
    @ObservedObject var appState: AppState
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Properties")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(AppForgeTheme.textTertiary)
                .padding(.horizontal, 12).padding(.vertical, 10)
            
            Divider().background(AppForgeTheme.border)
            
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    switch activeTool {
                    case .extrude:
                        PropSection("Extrude") {
                            PropSlider("Distance", 25, 0, 100, "mm")
                            PropToggle("Both Sides", false)
                            PropSlider("Taper Angle", 0, -45, 45, "°")
                        }
                    case .fillet:
                        PropSection("Fillet") {
                            PropSlider("Radius", 2.5, 0.01, 50, "mm")
                            PropPicker("Type", ["Constant", "Variable", "Chordal"])
                        }
                    case .shell:
                        PropSection("Shell") {
                            PropSlider("Thickness", 2.0, 0.1, 20, "mm")
                            PropToggle("Inside", true)
                        }
                    case .boolean:
                        PropSection("Boolean") {
                            PropPicker("Operation", ["Union", "Subtract", "Intersect"])
                            PropToggle("Keep Originals", false)
                        }
                    default:
                        PropSection("Selection") {
                            Text("No object selected").font(.system(size: 10)).foregroundColor(AppForgeTheme.textTertiary)
                        }
                    }
                }
                .padding(12)
            }
        }
        .frame(width: 220)
        .background(AppForgeTheme.surface)
        .overlay(alignment: .leading) {
            Rectangle().fill(AppForgeTheme.border).frame(width: 1)
        }
    }
}

struct PropSection<Content: View>: View {
    let title: String; let content: Content
    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title; self.content = content()
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.system(size: 10, weight: .medium)).foregroundColor(AppForgeTheme.textSecondary)
            content
        }
    }
}

struct PropSlider: View {
    let label: String; let value: Double; let min: Double; let max: Double; let unit: String
    @State private var sliderValue: Double
    init(_ label: String, _ value: Double, _ min: Double, _ max: Double, _ unit: String) {
        self.label = label; self.value = value; self.min = min; self.max = max; self.unit = unit
        self._sliderValue = State(initialValue: value)
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(label).font(.system(size: 10)).foregroundColor(AppForgeTheme.textTertiary)
                Spacer()
                Text("\(String(format: "%.1f", sliderValue)) \(unit)").font(.system(size: 10, weight: .medium)).foregroundColor(AppForgeTheme.textPrimary)
            }
            Slider(value: $sliderValue, in: min...max).tint(AppForgeTheme.accent)
        }
    }
}

struct PropToggle: View {
    let label: String; @State var isOn: Bool
    init(_ label: String, _ isOn: Bool) { self.label = label; self._isOn = State(initialValue: isOn) }
    var body: some View {
        Toggle(isOn: $isOn) {
            Text(label).font(.system(size: 10)).foregroundColor(AppForgeTheme.textTertiary)
        }.toggleStyle(.switch).tint(AppForgeTheme.accent)
    }
}

struct PropPicker: View {
    let label: String; let options: [String]; @State var selection: String
    init(_ label: String, _ options: [String]) { self.label = label; self.options = options; self._selection = State(initialValue: options[0]) }
    var body: some View {
        HStack {
            Text(label).font(.system(size: 10)).foregroundColor(AppForgeTheme.textTertiary)
            Spacer()
            Picker("", selection: $selection) {
                ForEach(options, id: \.self) { Text($0).font(.system(size: 10)) }
            }.pickerStyle(.menu).tint(AppForgeTheme.accent)
        }
    }
}

// MARK: - Bottom Mode Bar

struct AppForgeModeBar: View {
    @Binding var selectedMode: AppState.AppMode
    @Binding var showLeftPanel: Bool
    @Binding var showRightPanel: Bool
    
    let modes: [(AppState.AppMode, String)] = [
        (.cad, "rectangle.3.group"), (.sculpt, "scribble.variable"),
        (.paint, "paintbrush.pointed"), (.animation, "film"),
        (.render, "camera.aperture"),
    ]
    
    var body: some View {
        HStack(spacing: 0) {
            Button(action: { showLeftPanel.toggle() }) {
                Image(systemName: "sidebar.left")
                    .font(.system(size: 14))
                    .foregroundColor(showLeftPanel ? AppForgeTheme.accent : AppForgeTheme.textTertiary)
                    .frame(width: 36, height: 36)
            }
            
            Spacer()
            
            ForEach(modes, id: \.0) { mode, icon in
                Button(action: { withAnimation { selectedMode = mode } }) {
                    VStack(spacing: 2) {
                        Image(systemName: icon)
                            .font(.system(size: 16))
                        Text("\(mode)".capitalized)
                            .font(.system(size: 8))
                    }
                    .foregroundColor(selectedMode == mode ? .white : AppForgeTheme.textTertiary)
                    .frame(width: 56, height: 40)
                    .background(selectedMode == mode ? AppForgeTheme.accent.opacity(0.1) : Color.clear)
                    .cornerRadius(8)
                }
            }
            
            Spacer()
            
            Button(action: { showRightPanel.toggle() }) {
                Image(systemName: "sidebar.right")
                    .font(.system(size: 14))
                    .foregroundColor(showRightPanel ? AppForgeTheme.accent : AppForgeTheme.textTertiary)
                    .frame(width: 36, height: 36)
            }
        }
        .padding(.horizontal, 8)
        .frame(height: 48)
        .background(AppForgeTheme.surface.opacity(0.95))
        .overlay(alignment: .top) {
            Rectangle().fill(AppForgeTheme.border).frame(height: 1)
        }
    }
}
