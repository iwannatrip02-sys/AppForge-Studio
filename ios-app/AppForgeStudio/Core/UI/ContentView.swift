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
    /// Transformación directa (Mover/Rotar/Escalar sobre el cuerpo arrastrado).
    var transformEnabled: Bool = false
    var onTransformBegan: ((SurfaceHit) -> Void)? = nil
    var onTransformChanged: ((Float, Float) -> Void)? = nil
    var onTransformEnded: (() -> Void)? = nil
    /// Tap en vacío → deseleccionar (el modo dueño decide qué limpiar).
    var onEmptyTap: (() -> Void)? = nil
    /// Gizmo de transformación (centro mundo + longitud + drag por eje).
    var gizmoCenter: SIMD3<Float>? = nil
    var gizmoAxisLength: Float = 1.0
    /// 0 = flechas, 1 = anillos de rotación.
    var gizmoStyle: Int = 0
    var onGizmoDragBegan: ((SIMD3<Float>) -> Void)? = nil
    /// Sketch en el plano de trabajo (taps + trazo vivo de pencil).
    var sketchInputEnabled: Bool = false
    var onSketchTap: ((SIMD2<Float>) -> Void)? = nil
    var onSketchDragBegan: ((SIMD2<Float>) -> Void)? = nil
    var onSketchDragChanged: ((SIMD2<Float>) -> Void)? = nil
    var onSketchDragEnded: ((SIMD2<Float>) -> Void)? = nil
    /// Plano de trabajo del boceto (para dibujar sobre una cara arbitraria).
    var sketchPlaneOrigin: SIMD3<Float> = .zero
    var sketchPlaneNormal: SIMD3<Float> = SIMD3(0, 1, 0)
    var sketchPlaneU: SIMD3<Float> = SIMD3(1, 0, 0)
    var sketchPlaneV: SIMD3<Float> = SIMD3(0, 0, 1)
    /// Tap sobre una cara plana con herramienta de dibujo → definir el plano.
    var onSketchFaceTap: ((SurfaceHit) -> Void)? = nil
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
                onFrameGesture: { HapticService.shared.medium(); canvasVM.resetView() },
                transformEnabled: transformEnabled,
                onTransformBegan: onTransformBegan,
                onTransformChanged: onTransformChanged,
                onTransformEnded: onTransformEnded,
                onEmptyTap: onEmptyTap,
                gizmoCenter: gizmoCenter,
                gizmoAxisLength: gizmoAxisLength,
                gizmoStyle: gizmoStyle,
                onGizmoDragBegan: onGizmoDragBegan,
                sketchInputEnabled: sketchInputEnabled,
                onSketchTap: onSketchTap,
                onSketchDragBegan: onSketchDragBegan,
                onSketchDragChanged: onSketchDragChanged,
                onSketchDragEnded: onSketchDragEnded,
                sketchPlaneOrigin: sketchPlaneOrigin,
                sketchPlaneNormal: sketchPlaneNormal,
                sketchPlaneU: sketchPlaneU,
                sketchPlaneV: sketchPlaneV,
                onSketchFaceTap: onSketchFaceTap)
                .edgesIgnoringSafeArea(.all)

            // HUD de diagnóstico (build de diagnóstico): convierte el device del
            // usuario en debugger — sin Mac no hay otra forma de ver el runtime.
            if renderer.diagnosticsEnabled {
                // SwiftUI. explícito: el proyecto tiene su propio TimelineView (animación)
                SwiftUI.TimelineView(.periodic(from: .now, by: 0.5)) { _ in
                    diagnosticsHUD
                }
                .allowsHitTesting(false)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(.top, 8)
                .padding(.leading, 8)
            }

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

    /// Líneas del HUD de diagnóstico. Lo que el usuario lee aquí ES el bug report.
    private var diagnosticsHUD: some View {
        let d = renderer.diagnostics()
        return VStack(alignment: .leading, spacing: 1) {
            Text("render \(d.renderCalls) · encoded \(d.encodedFrames) · rebuilds \(d.rebuilds)")
            Text("lib \(d.libraryOK ? "OK" : "FALLO") · basicPS \(d.basicPipelineOK ? "OK" : "NIL") · pbrPS \(d.pbrPipelineOK ? "OK" : "NIL") · sanity \(d.sanityPipelineOK ? "OK" : "NIL")")
            Text("drawable \(Int(d.drawableSize.width))×\(Int(d.drawableSize.height)) · obj b\(d.basicCount)/p\(d.pbrCount) · idx \(d.totalIndices)")
            Text(String(format: "cam (%.1f, %.1f, %.1f) → (%.1f, %.1f, %.1f)",
                        d.cameraPos.x, d.cameraPos.y, d.cameraPos.z,
                        d.cameraTarget.x, d.cameraTarget.y, d.cameraTarget.z))
            if let err = d.lastGPUError {
                Text("GPU: \(err)").foregroundColor(AppTheme.errorColor)
            }
        }
        .font(.system(size: 9, weight: .medium, design: .monospaced))
        .foregroundColor(AppTheme.textSecondaryColor)
        .padding(6)
        .background(Color.black.opacity(0.55))
        .cornerRadius(AppTheme.radiusSM)
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
