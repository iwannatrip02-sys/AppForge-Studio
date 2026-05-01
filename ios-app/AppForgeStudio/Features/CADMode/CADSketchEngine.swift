import SwiftUI

class CADSketchEngine: ObservableObject {
    @Published var sketchPoints: [CGPoint] = []
    @Published var sketchLines: [(CGPoint, CGPoint)] = []
    @Published var currentTool: SketchTool = .line
    @Published var constraintManager = GeometryConstraintManager()
    
    func addPoint(_ point: CGPoint) {
        sketchPoints.append(point)
        if sketchPoints.count == 2 {
            sketchLines.append((sketchPoints[0], sketchPoints[1]))
            sketchPoints.removeAll()
            // Ahora resolveConstraints() existe en GeometryConstraintManager
            constraintManager.resolveConstraints()
        }
    }
    
    func clear() {
        sketchPoints.removeAll()
        sketchLines.removeAll()
    }
}