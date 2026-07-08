import SwiftUI
import Metal
import Satin

@main
struct AppForgeStudioApp: App {
    @StateObject private var appState = AppState()
    @State private var showOnboarding = !UserDefaults.standard.bool(forKey: "onboardingComplete")
    var body: some SwiftUI.Scene {
        WindowGroup {
            if showOnboarding {
                OnboardingFlow(showOnboarding: $showOnboarding)
                    .environmentObject(appState.themeManager)
            } else {
                WorkspaceView(appState: appState)
                    .environmentObject(appState.themeManager)
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
            AppTheme.bgCanvas.ignoresSafeArea()
            VStack(spacing: AppTheme.space6) {
                Spacer()
                Image(systemName: pages[step].0)
                    .font(.system(size: 56, weight: .thin))
                    .foregroundStyle(LinearGradient(colors: [AppTheme.accentColor, AppTheme.accentGlow], startPoint: .top, endPoint: .bottom))
                Text(pages[step].1).font(.system(size: 28, weight: .bold)).foregroundColor(AppTheme.textPrimaryColor)
                Text(pages[step].2).font(.system(size: 15)).foregroundColor(AppTheme.textSecondaryColor).multilineTextAlignment(.center)
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
                .background(AppTheme.accentColor)
                .cornerRadius(AppTheme.radiusLG)
                .padding(.bottom, 60)
            }
            .padding(40)
        }
    }
}

// MARK: - Main Workspace
//
// Regla (docs/DISENO_INTERFAZ.md): el chrome global es mínimo — una barra de
// modos abajo y un control de vista flotante. Cada modo aporta SU chrome
// contextual. Aquí NO hay paneles decorativos: todo actuador tiene efecto real.

struct WorkspaceView: View {
    @ObservedObject var appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            modeContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .overlay(alignment: .bottomTrailing) {
                    ViewCubeControl(canvasVM: appState.canvasVM)
                        .padding(.trailing, AppTheme.space3)
                        .padding(.bottom, 64)
                }
            BottomModeBar(appState: appState)
        }
        .background(AppTheme.bgCanvas)
        .onChange(of: appState.selectedMode) { newMode in
            // El modo Paint reutiliza la vista de Sculpt con el pipeline de pintura activo.
            appState.toolVM.isPaintMode = (newMode == .paint)
        }
    }

    /// Cada modo monta su vista REAL de Features/. (Antes el chrome era una
    /// maqueta que ignoraba selectedMode y toda la funcionalidad construida.)
    @ViewBuilder private var modeContent: some View {
        switch appState.selectedMode {
        case .cad:
            CADModeView(canvasVM: appState.canvasVM, renderer: appState.satinRenderer,
                        toolVM: appState.toolVM, animationVM: appState.animationVM)
        case .sculpt, .paint:
            SculptModeView(canvasVM: appState.canvasVM, renderer: appState.satinRenderer,
                           animationVM: appState.animationVM, toolVM: appState.toolVM,
                           subdivisionVM: appState.subdivisionVM)
        case .hybrid:
            HybridModeView(canvasVM: appState.canvasVM, renderer: appState.satinRenderer,
                           toolVM: appState.toolVM, animationVM: appState.animationVM,
                           subdivisionVM: appState.subdivisionVM,
                           layerManager: appState.layerManager)
        case .animation:
            AnimationModeView(canvasVM: appState.canvasVM, renderer: appState.satinRenderer,
                              toolVM: appState.toolVM, animationVM: appState.animationVM,
                              subdivisionVM: appState.subdivisionVM)
        case .render:
            RenderModeView(canvasVM: appState.canvasVM, renderer: appState.satinRenderer,
                           toolVM: appState.toolVM, animationVM: appState.animationVM,
                           subdivisionVM: appState.subdivisionVM,
                           materialVM: appState.materialEditorVM)
        }
    }
}

// MARK: - VIEW CUBE (control de cámara real)

/// Antes decorativo (chevrons sin acción). Ahora: chevrons orbitan ~45°,
/// el cubo central re-encuadra la escena. (ViewCubeControl y no ViewCube:
/// ese nombre ya lo usa el modelo de ViewportFeatures.swift.)
struct ViewCubeControl: View {
    let canvasVM: CanvasViewModel
    /// ≈45° con la sensibilidad de orbitCamera (0.005 rad/pt).
    private let step: CGFloat = 157

    var body: some View {
        VStack(spacing: 0) {
            cubeButton("chevron.up") { canvasVM.orbitCamera(delta: CGSize(width: 0, height: step)) }
                .frame(width: 24, height: 18)
            HStack(spacing: 0) {
                cubeButton("chevron.left") { canvasVM.orbitCamera(delta: CGSize(width: -step, height: 0)) }
                    .frame(width: 18, height: 24)
                Button(action: { HapticService.shared.medium(); canvasVM.resetView() }) {
                    Image(systemName: "cube").font(.system(size: 16)).foregroundColor(AppTheme.accentColor)
                }
                .accessibilityLabel("Re-encuadrar")
                cubeButton("chevron.right") { canvasVM.orbitCamera(delta: CGSize(width: step, height: 0)) }
                    .frame(width: 18, height: 24)
            }
            cubeButton("chevron.down") { canvasVM.orbitCamera(delta: CGSize(width: 0, height: -step)) }
                .frame(width: 24, height: 18)
        }
        .glassPanel()
    }

    private func cubeButton(_ icon: String, action: @escaping () -> Void) -> some View {
        Button(action: { HapticService.shared.light(); action() }) {
            Image(systemName: icon).font(.system(size: 9)).foregroundColor(AppTheme.textTertiary)
        }
    }
}

// MARK: - BOTTOM MODE BAR

struct BottomModeBar: View {
    @ObservedObject var appState: AppState

    let modes: [(AppState.AppMode, String, String)] = [
        (.cad, "cube.transparent", "CAD"),
        (.sculpt, "scribble.variable", "Sculpt"),
        (.paint, "paintbrush.pointed", "Paint"),
        (.hybrid, "square.3.layers.3d", "Híbrido"),
        (.animation, "film", "Animar"),
        (.render, "camera.aperture", "Render"),
    ]

    var body: some View {
        HStack(spacing: 0) {
            Spacer()
            ForEach(modes, id: \.0) { mode, icon, label in
                Button(action: {
                    HapticService.shared.light()
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { appState.selectedMode = mode }
                }) {
                    VStack(spacing: 2) {
                        Image(systemName: icon).font(.system(size: 17))
                        Text(label).font(.system(size: 8, weight: appState.selectedMode == mode ? .semibold : .regular))
                    }
                    .foregroundColor(appState.selectedMode == mode ? AppTheme.accentColor : AppTheme.textTertiary)
                    .frame(width: 56, height: 44)
                    .background(appState.selectedMode == mode ? AppTheme.accentColor.opacity(0.08) : Color.clear)
                    .cornerRadius(AppTheme.radiusSM)
                }
            }
            Spacer()
        }
        .padding(.horizontal, AppTheme.space2)
        .frame(height: 50)
        .glassPanel()
        .padding(.horizontal, AppTheme.space2)
        .padding(.bottom, AppTheme.space1)
    }
}
