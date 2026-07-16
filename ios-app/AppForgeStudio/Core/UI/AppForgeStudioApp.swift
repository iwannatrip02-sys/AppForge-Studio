import SwiftUI
import Metal
import Satin
import UIKit
import OSLog

@main
struct AppForgeStudioApp: App {
    @StateObject private var appState = AppState()
    @State private var showOnboarding: Bool
    /// Inicio (galería de proyectos) — la puerta de entrada tras el onboarding.
    @State private var showHome: Bool
    @Environment(\.scenePhase) private var scenePhase

    init() {
        // ARNÉS UI-PROBE (solo con el launch-argument `-UIProbeMode`; en
        // producción no hace nada). Ver Sources/Services/UIProbeMode.swift.
        // Bajo el arnés: SELLA el onboarding y SALTA la galería (Home) para
        // montar directo el workspace — el flag debe leerse ANTES de fijar los
        // @State del gate, por eso se inicializan aquí y no en su declaración.
        if UIProbeMode.isActive {
            // Arnés completo: sella onboarding, salta home, monta workspace directo.
            UIProbeMode.sealOnboarding()
            _showOnboarding = State(initialValue: false)
            _showHome = State(initialValue: false)
        } else if ProcessInfo.processInfo.arguments.contains(UIProbeMode.skipOnboardingFlag) {
            // Solo skip de onboarding: sella el gate pero muestra Home normalmente.
            // G-A lanza con este flag para gestos libres sin arnés auto-secuencia.
            UIProbeMode.sealOnboarding()
            _showOnboarding = State(initialValue: false)
            _showHome = State(initialValue: true)
        } else {
            _showOnboarding = State(initialValue: !UserDefaults.standard.bool(forKey: "onboardingComplete"))
            _showHome = State(initialValue: true)
        }
    }

    /// Pide orientación LANDSCAPE al window scene activo (API iOS 16+:
    /// `UIWindowScene.requestGeometryUpdate`). Solo se llama bajo el arnés; en un
    /// iPad la app ya soporta landscape, así que esto solo fuerza el arranque.
    @MainActor
    private func requestLandscapeOrientation() {
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }) ?? UIApplication.shared
            .connectedScenes.compactMap({ $0 as? UIWindowScene }).first else { return }
        scene.requestGeometryUpdate(.iOS(interfaceOrientations: .landscapeRight)) { error in
            // Mejor esfuerzo: si el device/simulador rechaza el update, seguimos.
            Logger(subsystem: "com.appforgestudio", category: "UIProbe")
                .error("PROBE: requestGeometryUpdate landscape falló: \(error.localizedDescription)")
        }
    }

    var body: some SwiftUI.Scene {
        WindowGroup {
            Group {
                if showOnboarding {
                    OnboardingFlow(showOnboarding: $showOnboarding)
                        .environmentObject(appState.themeManager)
                        .tint(AppTheme.accentColor)
                } else if showHome {
                    HomeView { url in
                        if let url { appState.openProject(at: url) } else { appState.newProject() }
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                            showHome = false
                        }
                    }
                    .environmentObject(appState.themeManager)
                    .preferredColorScheme(.dark)
                    .tint(AppTheme.accentColor)
                } else {
                    WorkspaceView(appState: appState, onHome: {
                        // Volver al Inicio GUARDA el documento (no hay "perder trabajo")
                        appState.saveCurrentProject()
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                            showHome = true
                        }
                    })
                    .environmentObject(appState.themeManager)
                    .preferredColorScheme(.dark)
                    // Tint global: TODOS los controles del sistema (sliders, toggles,
                    // borderedProminent) hablan brasa, no el azul de iOS.
                    .tint(AppTheme.accentColor)
                }
            }
            .task {
                // VISUALIZADOR DE TOQUES: instalar si `-UIProbeTouchViz` está presente.
                // Se activa también sin `-UIProbeMode` (el arnés GearScenarioTests lo
                // pasa junto con `-UIProbeSkipOnboarding`). Cero efecto sin el flag.
                if UIProbeMode.touchVizActive {
                    let scene = UIApplication.shared.connectedScenes
                        .compactMap({ $0 as? UIWindowScene })
                        .first(where: { $0.activationState == .foregroundActive })
                        ?? UIApplication.shared.connectedScenes
                        .compactMap({ $0 as? UIWindowScene }).first
                    if let scene { TouchVisualizer.installIfNeeded(in: scene) }
                }

                // ARNÉS UI-PROBE: solo con `-UIProbeMode`. Pide LANDSCAPE, abre un
                // proyecto nuevo y corre la secuencia cronometrada sobre los VM
                // reales. En producción `isActive == false` → no-op.
                guard UIProbeMode.isActive else { return }
                requestLandscapeOrientation()
                appState.newProject()
                await UIProbeMode.run(appState: appState)
            }
            .onChange(of: scenePhase) { phase in
                // App al fondo con documento abierto → guardar (nivel Shapr3D:
                // jamás se pierde trabajo, sin diálogos).
                if phase == .background, !showHome, !showOnboarding {
                    appState.saveCurrentProject()
                }
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
        ("paintbrush.pointed.fill", "Materiales PBR", "Render IBL en tiempo real.\nPresets físicos de material.\nTu modelo, listo para enseñar."),
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
    /// Volver al Inicio (galería). nil = sin botón (compatibilidad).
    var onHome: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 0) {
            modeContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                // Centrado en el borde derecho: no colisiona con toolbars superiores
                // ni con las barras inferiores (feedback: "mal posicionado").
                .overlay(alignment: .trailing) {
                    ViewCubeControl(canvasVM: appState.canvasVM)
                        .padding(.trailing, AppTheme.space2)
                        .opacity(0.85)
                }
            BottomModeBar(appState: appState, onHome: onHome)
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
    var onHome: (() -> Void)? = nil

    let modes: [(AppState.AppMode, String, String)] = [
        (.cad, "cube.transparent", "CAD"),
        (.sculpt, "scribble.variable", "Esculpir"),
        (.paint, "paintbrush.pointed", "Pintar"),
        (.hybrid, "square.3.layers.3d", "Híbrido"),
        (.animation, "film", "Animar"),
        (.render, "camera.aperture", "Render"),
    ]

    var body: some View {
        HStack(spacing: 0) {
            // Inicio: guarda el documento y vuelve a la galería de proyectos
            if let onHome {
                Button(action: { HapticService.shared.light(); onHome() }) {
                    VStack(spacing: 2) {
                        Image(systemName: "square.grid.2x2").font(.system(size: 17))
                        Text(appState.currentProjectName)
                            .font(.system(size: 8))
                            .lineLimit(1)
                    }
                    .foregroundColor(AppTheme.textTertiary)
                    .frame(width: 72, height: 44)
                }
                .accessibilityLabel("Volver a proyectos (guarda)")
            }
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
