import SwiftUI
import Metal
import Satin
import OSLog

private let logger = Logger(subsystem: "com.appforgestudio", category: "AppForgeStudioApp")
@main
struct AppForgeStudioApp: App {
    @StateObject private var appState = AppState()
    @State private var showOnboarding = !UserDefaults.standard.bool(forKey: "onboardingComplete")
    @Namespace private var modeTransition

    var body: some Scene {
        WindowGroup {
            AppRootView(appState: appState, showOnboarding: $showOnboarding, modeTransition: modeTransition)
        }
    }
}

struct AppRootView: View {
    @ObservedObject var appState: AppState
    @Binding var showOnboarding: Bool
    var modeTransition: Namespace.ID
    @State private var showLayerPanel = false
    @State private var showPreferences = false
    @Environment(\.colorScheme) private var systemColorScheme

    var body: some View {
        Group {
            if showOnboarding {
                OnboardingView(isOnboardingComplete: $showOnboarding)
                    .environmentObject(appState.themeManager)
                    .transition(.opacity)
            } else if appState.isLoading {
                LoadingScreenView()
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
                            withAnimation(.easeInOut(duration: 0.6)) {
                                appState.isLoading = false
                            }
                        }
                    }
            } else {
                NavigationStack {
                    ZStack {
                        appState.themeManager.currentTheme.background
                            .edgesIgnoringSafeArea(.all)

                        VStack(spacing: 0) {
                            ToolbarView(toolVM: appState.toolVM, scene: $appState.canvasVM.scene)
                                .environmentObject(appState.themeManager)
                                .padding(.horizontal)
                                .padding(.vertical, 4)

                            Group {
                                switch appState.selectedMode {
                                case .cad:
                                    CADModeView(canvasVM: appState.canvasVM, renderer: appState.satinRenderer, toolVM: appState.toolVM, animationVM: appState.animationVM)
                                        .environmentObject(appState.themeManager)
                                        .equatable()
                                        .matchedGeometryEffect(id: "mode-cad", in: modeTransition)
                                        .transition(.opacity.combined(with: .slide))
                                case .sculpt:
                                    SculptModeView(canvasVM: appState.canvasVM, renderer: appState.satinRenderer, toolVM: appState.toolVM, animationVM: appState.animationVM, subdivisionVM: appState.subdivisionVM)
                                        .environmentObject(appState.themeManager)
                                        .equatable()
                                        .matchedGeometryEffect(id: "mode-sculpt", in: modeTransition)
                                        .transition(.opacity.combined(with: .slide))
                                case .hybrid:
                                    HybridModeView(canvasVM: appState.canvasVM, renderer: appState.satinRenderer, toolVM: appState.toolVM, animationVM: appState.animationVM, subdivisionVM: appState.subdivisionVM)
                                        .environmentObject(appState.themeManager)
                                        .equatable()
                                        .matchedGeometryEffect(id: "mode-hybrid", in: modeTransition)
                                        .transition(.opacity.combined(with: .slide))
                                case .animation:
                                    AnimationModeView(canvasVM: appState.canvasVM, renderer: appState.satinRenderer, toolVM: appState.toolVM, animationVM: appState.animationVM, subdivisionVM: appState.subdivisionVM)
                                        .environmentObject(appState.themeManager)
                                        .equatable()
                                        .matchedGeometryEffect(id: "mode-animation", in: modeTransition)
                                        .transition(.opacity.combined(with: .slide))
                                case .render:
                                    RenderModeView(canvasVM: appState.canvasVM, renderer: appState.satinRenderer, toolVM: appState.toolVM, animationVM: appState.animationVM, subdivisionVM: appState.subdivisionVM, materialVM: appState.materialEditorVM)
                                        .environmentObject(appState.themeManager)
                                        .equatable()
                                        .matchedGeometryEffect(id: "mode-render", in: modeTransition)
                                        .transition(.opacity.combined(with: .slide))
                                }
                            }
                            .animation(.easeInOut(duration: 0.3), value: appState.selectedMode)

                            ModeSelectorView(selectedMode: $appState.selectedMode, themeManager: appState.themeManager)
                                .padding(.horizontal)
                                .padding(.vertical, 4)
                        }
                        
                        // Tool menu flotante
                        ToolMenuView(selectedTool: $appState.toolVM.selectedTool)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                            .padding()
                        
                        // Transformation gizmo condicional
                        if appState.canvasVM.selectedModelIndex != nil,
                           let transform = appState.canvasVM.selectedTransform {
                            TransformationGizmoView(
                                position: Binding(
                                    get: { transform.position },
                                    set: { appState.canvasVM.selectedTransform?.position = $0 }
                                ),
                                rotation: Binding(
                                    get: { transform.rotation },
                                    set: { appState.canvasVM.selectedTransform?.rotation = $0 }
                                ),
                                scale: Binding(
                                    get: { transform.scale },
                                    set: { appState.canvasVM.selectedTransform?.scale = $0 }
                                )
                            )
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                        }
                    }
                    .toolbar {
                        ToolbarItemGroup(placement: .navigationBarTrailing) {
                            Button(action: { showLayerPanel.toggle() }) {
                                Image(systemName: "layers")
                            }
                            Button(action: { showPreferences.toggle() }) {
                                Image(systemName: "gear")
                            }
                        }
                    }
                    .edgesIgnoringSafeArea(.all)
                }
                .sheet(isPresented: $showLayerPanel) {
                    LayerPanelView(sceneManager: SceneManager.shared, isPresented: $showLayerPanel)
                }
                .sheet(isPresented: $showPreferences) {
                    PreferencesView()
                }
                .preferredColorScheme(appState.isDarkMode ? .dark : .light)
            }
        }
        .preferredColorScheme(appState.themeManager.preferredColorScheme)
        .onChange(of: systemColorScheme) { newScheme in
            appState.themeManager.updateForColorScheme(newScheme)
        }
        .onAppear {
            appState.themeManager.updateForColorScheme(systemColorScheme)
        }
    }
}