import SwiftUI
import simd
import Metal
import Satin
import MetalKit

struct ContentView: View {
    @ObservedObject var canvasVM: CanvasViewModel
    var renderer: SatinRenderer
    var brushEngine: BrushEngine?
    var isPaintMode: Bool = false

    @State private var lastDrag: CGSize = .zero
    @State private var lastMagnification: CGFloat = 1.0
    @State private var currentStroke: BrushStroke?

    var body: some View {
        MetalView(scene: $canvasVM.scene, strokes: Binding(get: { canvasVM.scene.strokes }, set: { newVal in
            var s = canvasVM.scene
            s.strokes = newVal
            canvasVM.scene = s
        }, renderer: renderer, onTouch3D: handleTouch)
            .gesture(
                DragGesture(minimumDistance: isPaintMode ? 2 : 20)
                    .onChanged { value in
                        if !isPaintMode {
                            let delta = CGSize(
                                width: value.translation.width - lastDrag.width,
                                height: value.translation.height - lastDrag.height
                            )
                            canvasVM.orbitCamera(delta: delta)
                            lastDrag = value.translation
                        } else {
                            // Paint mode - start building stroke
                            if currentStroke == nil {
                                currentStroke = BrushStroke(brushType: brushEngine?.currentBrush ?? .round,
                                                           color: SIMD4<Float>(0, 0.5, 1, 1),
                                                           mode: .paint)
                            }
                        }
                    }
                    .onEnded { _ in
                        lastDrag = .zero
                        if isPaintMode, let s = currentStroke {
                            canvasVM.addStroke(s)
                            currentStroke = nil
                        }
                    }
            )
            .gesture(
                MagnificationGesture()
                    .onChanged { value in
                        if !isPaintMode {
                            let delta = value / lastMagnification
                            canvasVM.zoomCamera(delta: CGFloat(delta))
                            lastMagnification = value
                        }
                    }
                    .onEnded { _ in
                        lastMagnification = 1.0
                    }
            )
    }

    private func handleTouch(origin: SIMD3<Float>, direction: SIMD3<Float>) {
        if isPaintMode, let engine = brushEngine {
            let point = BrushPoint(position: origin, normal: direction, pressure: 1.0, tilt: .zero)
            if currentStroke != nil {
                currentStroke?.addPoint(point)
            }
        }
    }
}
