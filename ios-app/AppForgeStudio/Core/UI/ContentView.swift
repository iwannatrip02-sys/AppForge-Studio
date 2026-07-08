import SwiftUI
import simd
import Metal
import Satin
import MetalKit
import OSLog

private let logger = Logger(subsystem: "com.appforgestudio", category: "ContentView")
struct ContentView: View {
    @ObservedObject var canvasVM: CanvasViewModel
    var renderer: SatinRenderer
    // TODO(F3): BrushEngine deleted — paint brush support pending reimplementation
    var brushEngine: AnyObject? = nil
    var isPaintMode: Bool = false
    /// Propagado a MetalView: hit real al tocar geometría (push/pull, selección de caras)
    var onSurfaceHit: ((SurfaceHit) -> Void)? = nil
    /// Activa el router drag-sobre-geometría = esculpir (solo modos Sculpt/Hybrid).
    var sculptEnabled: Bool = false
    /// Undo/redo por gesto (tap 2/3 dedos). nil = undo de escena (canvasVM).
    /// CADModeView enchufa BRepHistory; SculptModeView enchufa el stack del SculptEngine.
    var onUndoGesture: (() -> Void)? = nil
    var onRedoGesture: (() -> Void)? = nil
    @EnvironmentObject var themeManager: ThemeManager

    @State private var currentStroke: BrushStroke?

    var body: some View {
        ZStack {
            MetalView(scene: $canvasVM.scene, strokes: Binding(get: { canvasVM.scene.strokes }, set: { newVal in
                var s = canvasVM.scene
                s.strokes = newVal
                canvasVM.scene = s
            }), renderer: renderer, animationEngine: canvasVM.animationEngine, onTouch3D: handleTouch, onSurfaceHit: onSurfaceHit, metalBackground: themeManager.currentTheme.metalBackground, sculptEnabled: sculptEnabled,
                onUndoGesture: onUndoGesture ?? { HapticService.shared.light(); canvasVM.undo() },
                onRedoGesture: onRedoGesture ?? { HapticService.shared.light(); canvasVM.redo() },
                onFrameGesture: { HapticService.shared.medium(); canvasVM.resetView() })
                .edgesIgnoringSafeArea(.all)

            VStack {
                Spacer()
                HStack {
                    Button(action: { HapticService.shared.light(); canvasVM.undo() }) {
                        Image(systemName: "arrow.uturn.backward")
                    }
                    .accessibilityLabel("Deshacer")
                    .dynamicTypeSize(...DynamicTypeSize.xLarge)

                    Button(action: { HapticService.shared.light(); canvasVM.redo() }) {
                        Image(systemName: "arrow.uturn.forward")
                    }
                    .accessibilityLabel("Rehacer")
                    .dynamicTypeSize(...DynamicTypeSize.xLarge)

                    Spacer()
                    Button(action: { HapticService.shared.medium(); canvasVM.resetView() }) {
                        Image(systemName: "arrow.counterclockwise")
                    }
                    .accessibilityLabel("Resetear vista")
                    .dynamicTypeSize(...DynamicTypeSize.xLarge)
                }
                .padding()
                .background(.ultraThinMaterial)
            }
        }
        // Órbita/zoom viven SOLO en MetalView (UIKit) — la duplicación SwiftUI
        // competía por la cámara y hacía errática la navegación. Aquí queda
        // únicamente la construcción de strokes de pintura.
        .gesture(
            DragGesture(minimumDistance: 2)
                .onChanged { _ in
                    if currentStroke == nil {
                        currentStroke = BrushStroke(brushType: .round,
                                                   color: SIMD4<Float>(0, 0.5, 1, 1),
                                                   mode: .paint)
                    }
                }
                .onEnded { _ in
                    if let s = currentStroke {
                        canvasVM.addStroke(s)
                        currentStroke = nil
                    }
                },
            including: isPaintMode ? .all : .subviews
        )
    }

    private func handleTouch(origin: SIMD3<Float>, direction: SIMD3<Float>) {
        if isPaintMode {
            let point = BrushPoint(position: origin, normal: direction, pressure: 1.0, tilt: .zero)
            if currentStroke != nil {
                currentStroke?.addPoint(point)
            }
        }
    }
}

extension CanvasViewModel {
    func orbitCamera(delta: CGSize) {
        let sensitivity: Float = 0.005
        var camera = scene.camera
        let right = simd_normalize(simd_cross(camera.target - camera.position, camera.up))
        let up = simd_normalize(camera.up)
        let rotY = simd_quatf(angle: Float(delta.width) * sensitivity, axis: up)
        let rotX = simd_quatf(angle: Float(delta.height) * sensitivity, axis: right)
        let offset = camera.position - camera.target
        let rotated = rotY * rotX * simd_quatf(real: 0, imag: offset)
        camera.position = camera.target + SIMD3<Float>(rotated.imag.x, rotated.imag.y, rotated.imag.z)
        scene.camera = camera
    }

    func zoomCamera(delta: CGFloat) {
        var camera = scene.camera
        let dir = simd_normalize(camera.target - camera.position)
        let distance = simd_length(camera.target - camera.position)
        let newDistance = distance / Float(delta)
        camera.position = camera.target - dir * min(max(newDistance, 0.5), 20.0)
        scene.camera = camera
    }

    func addStroke(_ stroke: BrushStroke) {
        var s = scene
        s.strokes.append(stroke)
        scene = s
    }
}
