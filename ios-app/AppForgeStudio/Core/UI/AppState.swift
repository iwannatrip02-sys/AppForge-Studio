import SwiftUI
import Combine
import Metal
import Satin
import MetalKit
import OSLog

private let logger = Logger(subsystem: "com.appforgestudio", category: "AppState")
@MainActor
class AppState: ObservableObject {
    @Published var selectedMode: AppMode = .cad
    @Published var isLoading: Bool = true
    @Published var isDarkMode: Bool = true
    @Published var showExport: Bool = false
    
    func toggleDarkMode() {
        isDarkMode.toggle()
    }
    let themeManager: ThemeManager
    let canvasVM: CanvasViewModel
    let toolVM: ToolViewModel
    let modelCache: ModelCacheService
    let modelLoader: ModelLoadService
    let exportVM: ExportViewModel
    lazy var animationVM: AnimationEngine = {
        AnimationEngine()
    }()
    let subdivisionVM: SubdivisionEngine
    lazy var materialEditorVM: MaterialEditorViewModel = {
        MaterialEditorViewModel(canvasVM: canvasVM)
    }()
    var satinRenderer: SatinRenderer

    func setRenderer(_ renderer: SatinRenderer) {
        self.satinRenderer = renderer
        renderer.animationEngine = animationVM
        self.canvasVM.animationEngine = animationVM
        renderer.onTransformsApplied = { [weak self] transforms in
            guard let self = self else { return }
            var scene = self.canvasVM.scene
            for (modelId, transform) in transforms {
                if let idx = scene.models.firstIndex(where: { $0.id.uuidString == modelId || $0.name == modelId }) {
                    scene.models[idx].transform = transform
                }
            }
            self.canvasVM.scene = scene
        }
        animationVM.onFrame = { [weak self] _, transforms in
            guard let self = self else { return }
            var scene = self.canvasVM.scene
            for (modelId, transform) in transforms {
                if let idx = scene.models.firstIndex(where: { $0.id.uuidString == modelId || $0.name == modelId }) {
                    scene.models[idx].transform = transform
                }
            }
            self.canvasVM.scene = scene
        }
    }

    enum AppMode: String, CaseIterable {
        case cad = "CAD"
        case sculpt = "Sculpt"
        case paint = "Paint"
        case animation = "Animation"
        case render = "Render"
    }

    init() {
        self.themeManager = ThemeManager()
        self.canvasVM = CanvasViewModel()
        self.toolVM = ToolViewModel()
        let device = MTLCreateSystemDefaultDevice() ??
            fatalError("Metal no soportado en este dispositivo")
        self.modelCache = ModelCacheService(device: device)
        self.modelLoader = ModelLoadService(device: device, cacheService: modelCache)
        self.exportVM = ExportViewModel(exportService: ExportService(device: device))
        self.subdivisionVM = SubdivisionEngine(device: device)
        
        let dummyView = MTKView(frame: .zero, device: device)
        let renderer = SatinRenderer(mtkView: dummyView)
        self.satinRenderer = renderer
        setRenderer(renderer)
    }

    var scene: Scene3D { canvasVM.scene }
    var strokes: [BrushStroke] { canvasVM.scene.strokes }
}