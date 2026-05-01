import SwiftUI

class BrushEngine: ObservableObject {
    @Published var brushSize: CGFloat = 0.02
    @Published var brushOpacity: CGFloat = 1.0
    @Published var brushColor: Color = .black
    @Published var isDrawing = false
    
    var strokePoints: [CGPoint] = []
    
    func startStroke(at point: CGPoint) {
        isDrawing = true
        strokePoints = [point]
    }
    
    func addStrokePoint(_ point: CGPoint) {
        guard isDrawing else { return }
        strokePoints.append(point)
    }
    
    func endStroke() {
        isDrawing = false
        strokePoints.removeAll()
    }
}
