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
    @EnvironmentObject var themeManager: ThemeManager

    @State private var lastDrag: CGSize = .zero
    @State private var lastMagnification: CGFloat = 1.0
    @State private var currentStroke: BrushStroke?

    var body: some View {
        ZStack {
            MetalView(scene: $canvasVM.scene, strokes: Binding(get: { canvasVM.scene.strokes }, set: { newVal in
                var s = canvasVM.scene
                s.strokes = newVal
                canvasVM.scene = s
            }), renderer: renderer, animationEngine: canvasVM.animationEngine, onTouch3D: handleTouch, metalBackground: themeManager.currentTheme.metalBackground)
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
                    Text("Mode: \(canvasVM.currentMode.rawValue)")
                        .font(.caption)
                        .padding(4)
                        .background(.ultraThinMaterial)
                        .cornerRadius(4)
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
                        if currentStroke == nil {
                            currentStroke = BrushStroke(brushType: .round,
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
