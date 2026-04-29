import SwiftUI
import Metal

@main
struct AppForgeStudioApp: App {
    @StateObject private var appState = AppState()
    @State private var showOnboarding = !UserDefaults.standard.bool(forKey: "onboardingComplete")

    var body: some Scene {
        WindowGroup {
            if showOnboarding {
                OnboardingView(isOnboardingComplete: $showOnboarding)
                    .transition(.opacity)
            } else {
                ZStack {
                    Color.black.edgesIgnoringSafeArea(.all)

                VStack(spacing: 0) {
                    // Top navigation
                    HStack {
                        Text("AppForge Studio")
                            .font(.headline)
                            .foregroundColor(.white)
                        Spacer()
                        HStack(spacing: 2) {
                            ForEach(AppState.AppMode.allCases, id: \.self) { mode in
                                Button(action: { appState.selectedMode = mode }) {
                                    Text(mode.rawValue)
                                        .font(.system(size: 12, weight: appState.selectedMode == mode ? .bold : .regular))
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(appState.selectedMode == mode ? Color.accentColor : Color.gray.opacity(0.3))
                                        .foregroundColor(.white)
                                        .cornerRadius(8)
                                }
                            }
                        }
                        Spacer()
                        Button(action: { appState.showExport = true }) {
                            Image(systemName: "square.and.arrow.up")
                                .foregroundColor(.white)
                        }
                        .disabled(appState.canvasVM.scene.models.isEmpty)
                    }
                }
            }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .background(Color.black.opacity(0.8))

                    // Content area based on selected mode
                    Group {
                        switch appState.selectedMode {
                        case .cad:
                            CADModeView(canvasVM: appState.canvasVM, renderer: appState.satinRenderer, toolVM: appState.toolVM, animationVM: appState.animationVM)
                                .equatable()
                        case .sculpt:
                            SculptModeView(canvasVM: appState.canvasVM, renderer: appState.satinRenderer, toolVM: appState.toolVM, subdivisionVM: appState.subdivisionVM)
                                .equatable()
                        case .hybrid:
                            HybridModeView(canvasVM: appState.canvasVM, renderer: appState.satinRenderer, toolVM: appState.toolVM, animationVM: appState.animationVM, subdivisionVM: appState.subdivisionVM)
                                .equatable()
                        case .render:
                            SatinRendererView(scene: Binding(get: { appState.scene }, set: { appState.canvasVM.scene = $0 }))
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .preferredColorScheme(.dark)
            .sheet(isPresented: $appState.showExport) {
                ExportView(exportVM: appState.exportVM, exportService: ExportService(device: MTLCreateSystemDefaultDevice() ?? nil!), model: appState.canvasVM.scene.models.first ?? Model(name: "Empty", meshes: []))
            }
            .environmentObject(appState)
        }
    }
}
