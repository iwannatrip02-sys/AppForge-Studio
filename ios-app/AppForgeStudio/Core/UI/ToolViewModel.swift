import Foundation
import simd
import SwiftUI
import OSLog

private let logger = Logger(subsystem: "com.appforgestudio", category: "ToolViewModel")
enum ActiveTool: String, CaseIterable {
    case select = "Seleccionar"
    case move = "Mover"
    case rotate = "Rotar"
    case scale = "Escalar"
    case brush = "Pincel"
    case extrude = "Extruir"
    case loopCut = "Loop Cut"
    case bevel = "Bisel"
    case boolean = "Booleano"
    case measure = "Medir"
}

enum ActiveMode: String, CaseIterable {
    case cad = "CAD"
    case sculpt = "Esculpir"
    case paint = "Pintar"
    case hybrid = "Hybrid"
    case render = "Render"
}

class ToolViewModel: ObservableObject {
    @Published var activeMode: ActiveMode = .hybrid
    @Published var activeTool: ActiveTool = .select
    @Published var brushSize: Float = 0.05
    @Published var brushHardness: Float = 0.8
    @Published var brushOpacity: Float = 1.0
    @Published var brushColor: SIMD4<Float> = SIMD4<Float>(0, 0, 0, 1)
    @Published var isSymmetryEnabled: Bool = false
    @Published var symmetryAxis: Int = 0
    @Published var gridSnapEnabled: Bool = true
    @Published var showMeasurements: Bool = false
    @Published var transformSpace: TransformSpace = .world
    
    enum TransformSpace: String, CaseIterable {
        case world = "Mundo"
        case local = "Local"
    }
    
    var availableTools: [ActiveTool] {
        switch activeMode {
        case .cad:
            return [.select, .move, .rotate, .scale, .extrude, .loopCut, .bevel, .boolean, .measure]
        case .sculpt, .paint:
            return [.brush, .move, .rotate, .scale]
        case .hybrid:
            return ActiveTool.allCases
        case .render:
            return [.select, .move, .rotate]
        }
    }
    
    func resetBrushDefaults() {
        brushSize = 0.05
        brushHardness = 0.8
        brushOpacity = 1.0
        isSymmetryEnabled = false
    }
    
    func setBrushFromPreset(_ preset: String) {
        switch preset {
        case "fine":
            brushSize = 0.01
            brushHardness = 0.9
            brushOpacity = 1.0
        case "medium":
            brushSize = 0.05
            brushHardness = 0.8
            brushOpacity = 0.8
        case "coarse":
            brushSize = 0.15
            brushHardness = 0.4
            brushOpacity = 0.5
        case "airbrush":
            brushSize = 0.08
            brushHardness = 0.2
            brushOpacity = 0.3
        default:
            resetBrushDefaults()
        }
    }
}
