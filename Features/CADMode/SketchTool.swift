import Foundation

enum SketchTool: String, CaseIterable, Identifiable {
    case line = "Line"
    case arc = "Arc"
    case circle = "Circle"
    case rectangle = "Rectangle"
    case trim = "Trim"
    case extend = "Extend"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .line: return "line.diagonal"
        case .arc: return "point.topleft.down.curvedto.point.bottomright.up"
        case .circle: return "circle"
        case .rectangle: return "rectangle"
        case .trim: return "scissors"
        case .extend: return "arrow.up.right"
        }
    }
}
