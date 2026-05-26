import SwiftUI
import Metal
import Satin

@main
struct AppForgeStudioApp: App {
    @StateObject private var appState = AppState()
    @State private var showOnboarding = !UserDefaults.standard.bool(forKey: "onboardingComplete")
    var body: some Scene {
        WindowGroup {
            if showOnboarding {
                OnboardingFlow(showOnboarding: $showOnboarding)
            } else {
                WorkspaceView(appState: appState)
                    .preferredColorScheme(.dark)
            }
        }
    }
}

// MARK: - Onboarding (minimal, elegant)

struct OnboardingFlow: View {
    @Binding var showOnboarding: Bool
    @State private var step = 0
    let pages = [
        ("cube.transparent.fill", "CAD Profesional", "Open CASCADE 8.0 kernel.\nBooleanas exactas. STEP/IGES.\nPrecisión industrial."),
        ("scribble.variable", "Escultura Libre", "10 deformers. Dynamic topology.\nVoxel remesh. Subdivisión.\nComo Nomad, pero con CAD."),
        ("paintbrush.pointed.fill", "Pintura PBR", "IBL pipeline. Metal compute.\nMateriales físicos en tiempo real.\nTu modelo, terminado."),
        ("gearshape.2.fill", "Listo", "Todo en una app. Gratis. Open-source.\nPara iPad. Sin suscripciones.")
    ]
    var body: some View {
        ZStack {
            AppForgeTheme.bgCanvas.ignoresSafeArea()
            VStack(spacing: AppForgeTheme.spXL) {
                Spacer()
                Image(systemName: pages[step].0)
                    .font(.system(size: 56, weight: .thin))
                    .foregroundStyle(LinearGradient(colors: [AppForgeTheme.accent, AppForgeTheme.accentGlow], startPoint: .top, endPoint: .bottom))
                Text(pages[step].1).font(.system(size: 28, weight: .bold)).foregroundColor(AppForgeTheme.textPri)
                Text(pages[step].2).font(.system(size: 15)).foregroundColor(AppForgeTheme.textSec).multilineTextAlignment(.center)
                Spacer()
                Button(step < 3 ? "Continuar" : "Comenzar") {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        if step < 3 { step += 1 }
                        else { UserDefaults.standard.set(true, forKey: "onboardingComplete"); showOnboarding = false }
                    }
                }
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 48).padding(.vertical, 14)
                .background(AppForgeTheme.accent)
                .cornerRadius(AppForgeTheme.rLG)
                .padding(.bottom, 60)
            }
            .padding(40)
        }
    }
}

// MARK: - Main Workspace

struct WorkspaceView: View {
    @ObservedObject var appState: AppState
    @State private var showLeftBar = true
    @State private var showRightPanel = false
    @State private var activeTool: String = "select"
    
    var body: some View {
        HStack(spacing: 0) {
            // ── LEFT TOOLBAR (48px, glass) ──
            if showLeftBar {
                LeftToolbar(activeTool: $activeTool, showLeftBar: $showLeftBar, appState: appState)
                    .transition(.move(edge: .leading).combined(with: .opacity))
            }
            
            // ── VIEWPORT ──
            ViewportArea(appState: appState, activeTool: $activeTool)
                .overlay(alignment: .top) { TopStatusBar(appState: appState) }
                .overlay(alignment: .bottomLeading) {
                    if activeTool != "select" { FloatingParams(activeTool: $activeTool) }
                }
                .overlay(alignment: .bottomTrailing) { MiniViewCube() }
            
            // ── RIGHT PANEL (220px, glass, conditional) ──
            if showRightPanel {
                RightProperties(activeTool: $activeTool, appState: appState)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .background(AppForgeTheme.bgCanvas)
        .overlay(alignment: .bottom) {
            BottomModeBar(appState: appState, showLeftBar: $showLeftBar, showRightPanel: $showRightPanel)
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: showLeftBar)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: showRightPanel)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: activeTool)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: appState.selectedMode)
    }
}

// MARK: - LEFT TOOLBAR

struct LeftToolbar: View {
    @Binding var activeTool: String
    @Binding var showLeftBar: Bool
    @ObservedObject var appState: AppState
    
    let tools: [(id: String, icon: String, label: String)] = [
        ("select", "arrow.up.left.and.arrow.down.right", "Select"),
        ("sketch", "pencil.and.outline", "Sketch"),
        ("extrude", "arrow.up.to.line.compact", "Extrude"),
        ("revolve", "arrow.triangle.2.circlepath", "Revolve"),
        ("fillet", "circle.lefthalf.filled.righthalf.striped.horizontal", "Fillet"),
        ("chamfer", "triangle.lefthalf.filled", "Chamfer"),
        ("shell", "square.dotted", "Shell"),
        ("loft", "rectangle.3.group.fill", "Loft"),
        ("sweep", "point.topleft.down.curvepath", "Sweep"),
        ("boolean", "circle.grid.cross.fill", "Boolean"),
        ("measure", "ruler", "Measure"),
    ]
    
    var body: some View {
        VStack(spacing: 2) {
            // Logo
            Image(systemName: "cube.transparent.fill")
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(LinearGradient(colors: [AppForgeTheme.accent, AppForgeTheme.accentGlow], startPoint: .top, endPoint: .bottom))
                .padding(.bottom, AppForgeTheme.spSM)
            
            Rectangle().fill(AppForgeTheme.border).frame(width: 24, height: 1)
                .padding(.vertical, AppForgeTheme.spXS)
            
            // Tools
            ScrollView(showsIndicators: false) {
                VStack(spacing: 1) {
                    ForEach(tools, id: \.id) { tool in
                        Button(action: {
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.6)) {
                                activeTool = tool.id
                            }
                        }) {
                            Image(systemName: tool.icon)
                                .font(.system(size: 17, weight: activeTool == tool.id ? .medium : .regular))
                                .frame(width: 40, height: 40)
                                .foregroundColor(activeTool == tool.id ? AppForgeTheme.accent : AppForgeTheme.textTer)
                                .toolbarGlow(active: activeTool == tool.id)
                        }
                        .help(tool.label)
                    }
                }
            }
            
            Spacer()
            
            Rectangle().fill(AppForgeTheme.border).frame(width: 24, height: 1)
                .padding(.vertical, AppForgeTheme.spXS)
            
            Button(action: { withAnimation { showLeftBar.toggle() } }) {
                Image(systemName: "sidebar.left")
                    .font(.system(size: 14)).frame(width: 40, height: 40)
                    .foregroundColor(AppForgeTheme.textTer)
            }
        }
        .padding(.vertical, AppForgeTheme.spSM)
        .frame(width: 52)
        .glassPanel()
        .padding(.leading, AppForgeTheme.spXS)
        .padding(.vertical, AppForgeTheme.spXS)
    }
}

// MARK: - VIEWPORT

struct ViewportArea: View {
    @ObservedObject var appState: AppState
    @Binding var activeTool: String
    
    var body: some View {
        ZStack {
            AppForgeTheme.bgCanvas
            ContentView(canvasVM: appState.canvasVM, renderer: appState.satinRenderer, brushEngine: appState.toolVM.brushEngine, isPaintMode: false)
        }
        .clipShape(RoundedRectangle(cornerRadius: AppForgeTheme.rLG))
        .padding(AppForgeTheme.spXS)
    }
}

// MARK: - TOP STATUS BAR

struct TopStatusBar: View {
    @ObservedObject var appState: AppState
    var body: some View {
        HStack(spacing: AppForgeTheme.spSM) {
            Text("AppForge Studio")
                .font(.system(size: 13, weight: .semibold)).foregroundColor(AppForgeTheme.textPri)
            Text("· Sin título").font(.system(size: 12)).foregroundColor(AppForgeTheme.textTer)
            Spacer()
            HStack(spacing: 6) {
                PillLabel("OCCT 8.0")
                PillLabel("PBR")
                PillLabel("60 FPS")
            }
        }
        .padding(.horizontal, AppForgeTheme.spLG)
        .padding(.vertical, AppForgeTheme.spXS)
        .background(AppForgeTheme.bgBase.opacity(0.8))
        .background(.ultraThinMaterial)
        .cornerRadius(AppForgeTheme.rMD)
        .padding(.horizontal, AppForgeTheme.spLG)
        .padding(.top, AppForgeTheme.spXS + 40)
    }
}

struct PillLabel: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text).font(.system(size: 9, weight: .medium)).foregroundColor(AppForgeTheme.textTer)
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(AppForgeTheme.bgOverlay).cornerRadius(3)
    }
}

// MARK: - FLOATING PARAMS (glass, contextual)

struct FloatingParams: View {
    @Binding var activeTool: String
    var body: some View {
        VStack(alignment: .leading, spacing: AppForgeTheme.spSM) {
            switch activeTool {
            case "extrude":
                ParamField("Distance", "25.0mm")
                ParamField("Direction", "Y+")
                ParamField("Taper", "0°")
                HStack(spacing: 4) {
                    ChipBtn("Solid", active: true)
                    ChipBtn("Cut")
                    ChipBtn("Both")
                }
            case "fillet":
                ParamField("Radius", "2.5mm")
                HStack(spacing: 4) {
                    ChipBtn("Constant", active: true)
                    ChipBtn("Variable")
                }
            case "shell":
                ParamField("Thickness", "2.0mm")
                HStack(spacing: 4) {
                    ChipBtn("Inside", active: true)
                    ChipBtn("Outside")
                    ChipBtn("Both")
                }
            case "boolean":
                HStack(spacing: 4) {
                    ChipBtn("Union", active: true, color: AppForgeTheme.axisGreen)
                    ChipBtn("Subtract", color: AppForgeTheme.axisRed)
                    ChipBtn("Intersect", color: AppForgeTheme.axisBlue)
                }
            default: EmptyView()
            }
        }
        .padding(AppForgeTheme.spMD)
        .glassPanel()
        .padding(.leading, AppForgeTheme.spLG)
        .padding(.bottom, AppForgeTheme.spXL + 48)
    }
}

struct ParamField: View {
    let label: String; let value: String
    init(_ label: String, _ value: String) { self.label = label; self.value = value }
    var body: some View {
        HStack(spacing: AppForgeTheme.spSM) {
            Text(label).font(.system(size: 10)).foregroundColor(AppForgeTheme.textTer)
            Spacer()
            Text(value).font(.system(size: 11, weight: .medium, design: .monospaced)).foregroundColor(AppForgeTheme.textPri)
        }
    }
}

struct ChipBtn: View {
    let label: String; var active = false; var color: Color = AppForgeTheme.accent
    var body: some View {
        Text(label).font(.system(size: 10, weight: active ? .bold : .regular))
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(active ? color.opacity(0.2) : AppForgeTheme.bgOverlay)
            .foregroundColor(active ? color : AppForgeTheme.textSec)
            .cornerRadius(4)
            .overlay(RoundedRectangle(cornerRadius: 4).stroke(active ? color.opacity(0.3) : Color.clear, lineWidth: 1))
    }
}

// MARK: - MINI VIEWCUBE

struct MiniViewCube: View {
    @State private var face: String = ""
    var body: some View {
        VStack(spacing: 0) {
            Button(action: {}) { Image(systemName: "chevron.up").font(.system(size: 9)).foregroundColor(AppForgeTheme.textTer) }.frame(width: 24, height: 18)
            HStack(spacing: 0) {
                Button(action: {}) { Image(systemName: "chevron.left").font(.system(size: 9)).foregroundColor(AppForgeTheme.textTer) }.frame(width: 18, height: 24)
                Image(systemName: "cube").font(.system(size: 16)).foregroundColor(AppForgeTheme.accent)
                Button(action: {}) { Image(systemName: "chevron.right").font(.system(size: 9)).foregroundColor(AppForgeTheme.textTer) }.frame(width: 18, height: 24)
            }
            Button(action: {}) { Image(systemName: "chevron.down").font(.system(size: 9)).foregroundColor(AppForgeTheme.textTer) }.frame(width: 24, height: 18)
        }
        .glassPanel()
        .padding(.trailing, AppForgeTheme.spLG)
        .padding(.bottom, AppForgeTheme.spXL + 48)
    }
}

// MARK: - RIGHT PROPERTIES PANEL

struct RightProperties: View {
    @Binding var activeTool: String
    @ObservedObject var appState: AppState
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppForgeTheme.spLG) {
                Text("Properties")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(AppForgeTheme.textTer)
                    .textCase(.uppercase)
                    .padding(.top, AppForgeTheme.spSM)
                
                PropGroup("Transform") {
                    PropRow("Position", "0, 0, 0")
                    PropRow("Rotation", "0°, 0°, 0°")
                    PropRow("Scale", "1.0, 1.0, 1.0")
                }
                
                switch activeTool {
                case "extrude":
                    PropGroup("Extrude") {
                        PropSlider("Distance", 25, 0, 100, "mm")
                        PropToggle("Solid", true)
                        PropToggle("Both Sides", false)
                    }
                case "fillet":
                    PropGroup("Fillet") {
                        PropSlider("Radius", 2.5, 0.01, 50, "mm")
                        PropSegmented("Type", ["Constant", "Variable", "Chordal"])
                    }
                case "shell":
                    PropGroup("Shell") {
                        PropSlider("Thickness", 2.0, 0.1, 20, "mm")
                        PropToggle("Inside", true)
                    }
                case "boolean":
                    PropGroup("Boolean") {
                        PropSegmented("Operation", ["Union", "Subtract", "Intersect"])
                        PropToggle("Keep Originals", false)
                    }
                default: EmptyView()
                }
            }
            .padding(.horizontal, AppForgeTheme.spMD)
        }
        .frame(width: 240)
        .glassPanel()
        .padding(.trailing, AppForgeTheme.spXS)
        .padding(.vertical, AppForgeTheme.spXS)
    }
}

struct PropGroup<Content: View>: View {
    let title: String; let content: Content
    init(_ title: String, @ViewBuilder content: () -> Content) { self.title = title; self.content = content() }
    var body: some View {
        VStack(alignment: .leading, spacing: AppForgeTheme.spSM) {
            Text(title).font(.system(size: 10, weight: .medium)).foregroundColor(AppForgeTheme.textSec)
            content
        }
        .padding(AppForgeTheme.spMD)
        .background(AppForgeTheme.bgBase.opacity(0.5))
        .cornerRadius(AppForgeTheme.rSM)
    }
}

struct PropRow: View {
    let label: String; let value: String
    init(_ label: String, _ value: String) { self.label = label; self.value = value }
    var body: some View {
        HStack { Text(label).font(.system(size: 10)).foregroundColor(AppForgeTheme.textTer); Spacer(); Text(value).font(.system(size: 10, weight: .medium, design: .monospaced)).foregroundColor(AppForgeTheme.textPri) }
    }
}

struct PropSlider: View {
    let label: String; @State var value: Double; let min: Double; let max: Double; let unit: String
    init(_ label: String, _ value: Double, _ min: Double, _ max: Double, _ unit: String) {
        self.label = label; self._value = State(initialValue: value); self.min = min; self.max = max; self.unit = unit
    }
    var body: some View {
        VStack(spacing: 2) {
            HStack { Text(label).font(.system(size: 10)).foregroundColor(AppForgeTheme.textTer); Spacer(); Text("\(value, specifier: "%.1f") \(unit)").font(.system(size: 10, weight: .medium, design: .monospaced)).foregroundColor(AppForgeTheme.textPri) }
            Slider(value: $value, in: min...max).tint(AppForgeTheme.accent)
        }
    }
}

struct PropToggle: View {
    let label: String; @State var isOn: Bool
    init(_ label: String, _ isOn: Bool) { self.label = label; self._isOn = State(initialValue: isOn) }
    var body: some View {
        Toggle(isOn: $isOn) { Text(label).font(.system(size: 10)).foregroundColor(AppForgeTheme.textTer) }.toggleStyle(.switch).tint(AppForgeTheme.accent)
    }
}

struct PropSegmented: View {
    let label: String; let options: [String]; @State var selected: String
    init(_ label: String, _ options: [String]) { self.label = label; self.options = options; self._selected = State(initialValue: options[0]) }
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.system(size: 10)).foregroundColor(AppForgeTheme.textTer)
            HStack(spacing: 1) {
                ForEach(options, id: \.self) { opt in
                    Button(action: { selected = opt }) {
                        Text(opt).font(.system(size: 9, weight: selected == opt ? .semibold : .regular))
                            .padding(.horizontal, 10).padding(.vertical, 4)
                            .background(selected == opt ? AppForgeTheme.accent.opacity(0.2) : AppForgeTheme.bgOverlay)
                            .foregroundColor(selected == opt ? AppForgeTheme.accent : AppForgeTheme.textSec)
                    }
                }
            }
            .cornerRadius(AppForgeTheme.rSM).overlay(RoundedRectangle(cornerRadius: AppForgeTheme.rSM).stroke(AppForgeTheme.border, lineWidth: 0.5))
        }
    }
}

// MARK: - BOTTOM MODE BAR

struct BottomModeBar: View {
    @ObservedObject var appState: AppState
    @Binding var showLeftBar: Bool
    @Binding var showRightPanel: Bool
    
    let modes: [(AppState.AppMode, String, String)] = [
        (.cad, "cube.transparent", "CAD"),
        (.sculpt, "scribble.variable", "Sculpt"),
        (.paint, "paintbrush.pointed", "Paint"),
        (.animation, "film", "Animate"),
        (.render, "camera.aperture", "Render"),
    ]
    
    var body: some View {
        HStack(spacing: 0) {
            Button(action: { withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { showLeftBar.toggle() } }) {
                Image(systemName: "sidebar.left")
                    .font(.system(size: 14)).frame(width: 40, height: 40)
                    .foregroundColor(showLeftBar ? AppForgeTheme.accent : AppForgeTheme.textTer)
            }
            Spacer()
            ForEach(modes, id: \.0) { mode, icon, label in
                Button(action: { withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { appState.selectedMode = mode } }) {
                    VStack(spacing: 2) {
                        Image(systemName: icon).font(.system(size: 17))
                        Text(label).font(.system(size: 8, weight: appState.selectedMode == mode ? .semibold : .regular))
                    }
                    .foregroundColor(appState.selectedMode == mode ? AppForgeTheme.accent : AppForgeTheme.textTer)
                    .frame(width: 56, height: 44)
                    .background(appState.selectedMode == mode ? AppForgeTheme.accent.opacity(0.08) : Color.clear)
                    .cornerRadius(AppForgeTheme.rSM)
                }
            }
            Spacer()
            Button(action: { withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { showRightPanel.toggle() } }) {
                Image(systemName: "sidebar.right")
                    .font(.system(size: 14)).frame(width: 40, height: 40)
                    .foregroundColor(showRightPanel ? AppForgeTheme.accent : AppForgeTheme.textTer)
            }
        }
        .padding(.horizontal, AppForgeTheme.spSM)
        .frame(height: 50)
        .glassPanel()
        .padding(.horizontal, AppForgeTheme.spSM)
        .padding(.bottom, AppForgeTheme.spXS)
    }
}
