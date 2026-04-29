import Foundation

@MainActor
class ToolViewModel: ObservableObject {
    @Published var selectedBrush: BrushType = .round
    @Published var radius: Float = 0.05
    @Published var hardness: Float = 0.8
    @Published var opacity: Float = 1.0
    @Published var color: SIMD4<Float> = SIMD4<Float>(0, 0, 0.8, 1)
    @Published var pressure: Float = 1.0
    @Published var symmetryEnabled: Bool = false
    @Published var symmetryAxis: Int = 0
    @Published var isPaintMode: Bool = false
    @Published var showExport: Bool = false
    @Published var showMeasurements: Bool = false
    @Published var gridSnapEnabled: Bool = true
    
    var brushEngine: BrushEngine {
        let engine = BrushEngine()
        engine.currentBrush = selectedBrush
        engine.radius = radius
        engine.hardness = hardness
        engine.opacity = opacity
        engine.color = color
        engine.pressure = pressure
        engine.symmetryEnabled = symmetryEnabled
        engine.symmetryAxis = symmetryAxis
        return engine
    }
}