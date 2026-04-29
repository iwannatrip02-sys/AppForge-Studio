import SwiftUI
import Combine

enum AppMode: String, CaseIterable {
    case CAD = "CAD"
    case Sculpt = "Sculpt"
    case Paint = "Paint"
    case Hybrid = "Hybrid"
    case Render = "Render"
}

class CanvasViewModel: ObservableObject {
    @Published var scene: Scene3D
    @Published var strokes: [BrushStroke]
    
    init() {
        self.scene = Scene3D()
        self.strokes = []
    }
}

class AppState: ObservableObject {
    @Published var selectedMode: AppMode = .Sculpt
    @Published var showExport: Bool = false
    @Published var canvasVM: CanvasViewModel
    @Published var satinRenderer: SatinRenderer?
    
    init() {
        self.canvasVM = CanvasViewModel()
    }
}