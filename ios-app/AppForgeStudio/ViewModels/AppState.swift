import SwiftUI
import Combine
import Metal
import Satin
import MetalKit

@MainActor
class AppState: ObservableObject {
    @Published var selectedMode: AppMode = .hybrid
    @Published var showExport = false

    let canvasVM: CanvasViewModel
    let toolVM: ToolViewModel
    let exportVM: ExportViewModel
    let animationVM: AnimationEngine
    let subdivisionVM: SubdivisionEngine
    var satinRenderer: SatinRenderer!

    enum AppMode: String, CaseIterable {
        case cad = "CAD"
        case sculpt = "Esculpir"
        case hybrid = "Hybrid"
        case render = "Render"
    }

    init() {
        self.canvasVM = CanvasViewModel()
        self.toolVM = ToolViewModel()
        let device = MTLCreateSystemDefaultDevice() ??
            fatalError("Metal no soportado en este dispositivo")
        self.exportVM = ExportViewModel(exportService: ExportService(device: device))
        let mtkView = MTKView()
        mtkView.device = device
        self.satinRenderer = SatinRenderer(mtkView: mtkView)
        self.satinRenderer.setup()
        self.animationVM = AnimationEngine(appState: self)
        self.subdivisionVM = SubdivisionEngine(device: device)
    }

    var scene: Scene3D { canvasVM.scene }
    var strokes: [BrushStroke] { canvasVM.scene.strokes }
}