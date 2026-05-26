import SwiftUI
import PencilKit
import OSLog

private let logger = Logger(subsystem: "com.appforgestudio", category: "PencilSketchView")

struct PencilSketchView: UIViewRepresentable {
    @Binding var isPencilMode: Bool
    @Binding var currentPressure: CGFloat
    var sketchEngine: CADSketchEngine
    var onStrokesImported: (([SketchEntity]) -> Void)?

    func makeCoordinator() -> Coordinator {
        Coordinator(sketchEngine: sketchEngine, onStrokesImported: onStrokesImported)
    }

    func makeUIView(context: Context) -> PKCanvasView {
        let canvas = PKCanvasView()
        canvas.drawingPolicy = .anyInput
        canvas.tool = PKInkingTool(.pen, color: .cyan, width: 2)
        canvas.delegate = context.coordinator
        canvas.isOpaque = false
        canvas.backgroundColor = .clear

        if let window = canvas.window {
            let toolPicker = PKToolPicker.shared(for: window)
            toolPicker?.setVisible(true, forFirstResponder: canvas)
        }

        context.coordinator.canvasView = canvas
        return canvas
    }

    func updateUIView(_ uiView: PKCanvasView, context: Context) {
        uiView.drawingPolicy = isPencilMode ? .anyInput : .pencilOnly
        if let window = uiView.window {
            let toolPicker = PKToolPicker.shared(for: window)
            toolPicker?.setVisible(isPencilMode, forFirstResponder: uiView)
        }
        context.coordinator.sketchEngine = sketchEngine
        context.coordinator.onStrokesImported = onStrokesImported
    }

    class Coordinator: NSObject, PKCanvasViewDelegate {
        var sketchEngine: CADSketchEngine
        var onStrokesImported: (([SketchEntity]) -> Void)?
        weak var canvasView: PKCanvasView?

        init(sketchEngine: CADSketchEngine, onStrokesImported: (([SketchEntity]) -> Void)?) {
            self.sketchEngine = sketchEngine
            self.onStrokesImported = onStrokesImported
        }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            let strokes = canvasView.drawing.strokes
            guard !strokes.isEmpty else { return }

            let entities = sketchEngine.importPencilKitStrokes(strokes)
            onStrokesImported?(entities)
            logger.info("PencilSketchView: imported \(entities.count) entities from \(strokes.count) strokes")
        }

        func canvasViewDidEndStroke(_ canvasView: PKCanvasView) {
            let entities = sketchEngine.importPencilKitStrokes(canvasView.drawing.strokes)
            onStrokesImported?(entities)
        }
    }
}

extension PencilSketchView.Coordinator {
    func updatePressure(from touches: Set<UITouch>, in canvas: PKCanvasView) {
        guard let touch = touches.first,
              touch.type == .pencil else { return }
        let force = touch.force / touch.maximumPossibleForce
        let clampedForce = max(0, min(1, CGFloat(force)))
        canvas.tool = PKInkingTool(.pen, color: .cyan, width: 1 + clampedForce * 8)
        sketchEngine.setStrokeWidth(clampedForce)
        logger.debug("Pencil pressure: \(clampedForce)")
    }
}
