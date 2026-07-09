import SwiftUI
import MetalKit
import simd
import Satin
import QuartzCore
import OSLog

private let logger = Logger(subsystem: "com.appforgestudio", category: "MetalView")

func perspective_fov(fov: Float, aspect: Float, near: Float, far: Float) -> float4x4 {
    let y = 1.0 / tan(fov * 0.5)
    let x = y / aspect
    let z = far / (far - near)
    return float4x4(SIMD4<Float>(x, 0, 0, 0), SIMD4<Float>(0, y, 0, 0), SIMD4<Float>(0, 0, z, 1), SIMD4<Float>(0, 0, -near * z, 0))
}

func lookAt(eye: SIMD3<Float>, target: SIMD3<Float>, up: SIMD3<Float>) -> float4x4 {
    let f = simd_normalize(target - eye)
    let s = simd_normalize(simd_cross(f, up))
    let u = simd_cross(s, f)
    return float4x4(SIMD4<Float>(s.x, u.x, -f.x, 0), SIMD4<Float>(s.y, u.y, -f.y, 0), SIMD4<Float>(s.z, u.z, -f.z, 0), SIMD4<Float>(-simd_dot(s, eye), -simd_dot(u, eye), simd_dot(f, eye), 1))
}

func rayTriangleIntersect(rayOrigin: SIMD3<Float>, rayDir: SIMD3<Float>, v0: SIMD3<Float>, v1: SIMD3<Float>, v2: SIMD3<Float>) -> SIMD3<Float>? {
    let edge1 = v1 - v0
    let edge2 = v2 - v0
    let h = simd_cross(rayDir, edge2)
    let a = simd_dot(edge1, h)
    if abs(a) < 0.0001 { return nil }
    let f = 1.0 / a
    let s = rayOrigin - v0
    let u = f * simd_dot(s, h)
    if u < 0.0 || u > 1.0 { return nil }
    let q = simd_cross(s, edge1)
    let v = f * simd_dot(rayDir, q)
    if v < 0.0 || u + v > 1.0 { return nil }
    let t = f * simd_dot(edge2, q)
    if t > 0.0001 { return rayOrigin + rayDir * t }
    return nil
}

struct MetalView: UIViewRepresentable {
    @Binding var scene: Scene3D
    @Binding var strokes: [BrushStroke]
    var renderer: SatinRenderer
    var animationEngine: AnimationEngine?
    var playbackController: AnimationPlaybackController?
    var onTouch3D: ((SIMD3<Float>, SIMD3<Float>) -> Void)?
    var onObjectSelected: ((Int?) -> Void)?
    var onSculptStroke: ((SculptPoint) -> Void)?
    /// Hit real de superficie (posición+normal+modelo) al tocar geometría —
    /// base de la manipulación directa (push/pull, selección de caras).
    var onSurfaceHit: ((SurfaceHit) -> Void)?
    var metalBackground: UIColor = .darkGray
    /// Contrato de gestos (DISENO_INTERFAZ §3): drag sobre geometría = herramienta,
    /// drag sobre vacío = orbitar. Solo el modo dueño del sculpt lo activa;
    /// en CAD/Animation/Render el drag de 1 dedo siempre orbita.
    var sculptEnabled: Bool = false
    /// Gestos globales (BLUEPRINT S9/N7): tap 2 dedos = deshacer, 3 = rehacer,
    /// doble tap = encuadrar. Cada modo enchufa su undo (B-rep, sculpt o escena).
    var onUndoGesture: (() -> Void)?
    var onRedoGesture: (() -> Void)?
    var onFrameGesture: (() -> Void)?
    /// Transformación directa (Mover/Rotar/Escalar): drag sobre un cuerpo lo
    /// transforma; drag sobre vacío sigue orbitando (contrato de gestos intacto).
    var transformEnabled: Bool = false
    var onTransformBegan: ((SurfaceHit) -> Void)?
    var onTransformChanged: ((Float, Float) -> Void)?
    var onTransformEnded: (() -> Void)?
    /// Tap sobre el vacío (sin hit): deseleccionar (contrato de gestos).
    var onEmptyTap: (() -> Void)?
    /// Gizmo de transformación: centro en mundo (nil = sin gizmo) + longitud de
    /// flecha. El drag que empieza sobre una manija restringe al eje tocado.
    var gizmoCenter: SIMD3<Float>?
    var gizmoAxisLength: Float = 1.0
    var onGizmoDragBegan: ((SIMD3<Float>) -> Void)?

    func makeCoordinator() -> Coordinator {
        let c = Coordinator(
            scene: $scene, strokes: $strokes,
            renderer: renderer, onTouch3D: onTouch3D,
            onObjectSelected: onObjectSelected,
            onSculptStroke: onSculptStroke,
            animationEngine: animationEngine
        )
        c.onSurfaceHit = onSurfaceHit
        c.sculptEnabled = sculptEnabled
        c.onUndoGesture = onUndoGesture
        c.onRedoGesture = onRedoGesture
        c.onFrameGesture = onFrameGesture
        c.transformEnabled = transformEnabled
        c.onTransformBegan = onTransformBegan
        c.onTransformChanged = onTransformChanged
        c.onTransformEnded = onTransformEnded
        c.onEmptyTap = onEmptyTap
        c.gizmoCenter = gizmoCenter
        c.gizmoAxisLength = gizmoAxisLength
        c.onGizmoDragBegan = onGizmoDragBegan
        return c
    }
    
    func makeUIView(context: UIViewRepresentableContext<MetalView>) -> MTKView {
        let v = MTKView()
        v.device = MTLCreateSystemDefaultDevice()
        v.delegate = context.coordinator
        v.backgroundColor = metalBackground
        v.depthStencilPixelFormat = .depth32Float
        // bgCanvas #0A0B10 (IDENTIDAD_FORGE §3): el viewport es el punto más oscuro
        // de la app — el modelo iluminado por PBR/IBL es el héroe.
        v.clearColor = MTLClearColor(red: 0.039, green: 0.043, blue: 0.063, alpha: 1.0)
        v.enableSetNeedsDisplay = true
        v.isPaused = false
        v.isMultipleTouchEnabled = true
        
        renderer.updateScene(scene)
        context.coordinator.setupGestures(v)
        
        return v
    }
    
    func updateUIView(_ uiView: MTKView, context: UIViewRepresentableContext<MetalView>) {
        renderer.updateScene(scene)
        renderer.animationEngine = animationEngine
        renderer.playbackController = playbackController
        context.coordinator.sculptEnabled = sculptEnabled
        context.coordinator.onUndoGesture = onUndoGesture
        context.coordinator.onRedoGesture = onRedoGesture
        context.coordinator.onFrameGesture = onFrameGesture
        context.coordinator.transformEnabled = transformEnabled
        context.coordinator.onTransformBegan = onTransformBegan
        context.coordinator.onTransformChanged = onTransformChanged
        context.coordinator.onTransformEnded = onTransformEnded
        context.coordinator.onEmptyTap = onEmptyTap
        context.coordinator.gizmoCenter = gizmoCenter
        context.coordinator.gizmoAxisLength = gizmoAxisLength
        context.coordinator.onGizmoDragBegan = onGizmoDragBegan
        uiView.backgroundColor = metalBackground
        uiView.setNeedsDisplay()
    }
    
    // MARK: - Coordinator
    
    class Coordinator: NSObject, MTKViewDelegate, UIGestureRecognizerDelegate {
        var renderer: SatinRenderer
        var animationEngine: AnimationEngine?
        @Binding var scene: Scene3D
        @Binding var strokes: [BrushStroke]
        var onTouch3D: ((SIMD3<Float>, SIMD3<Float>) -> Void)?
        var onObjectSelected: ((Int?) -> Void)?
        var onSculptStroke: ((SculptPoint) -> Void)?
        var onSurfaceHit: ((SurfaceHit) -> Void)?
        var onPinchExtrude: ((Float, Float) -> Void)?  // (distance, taper)
        var sculptEnabled: Bool = false
        var onUndoGesture: (() -> Void)?
        var onRedoGesture: (() -> Void)?
        var onFrameGesture: (() -> Void)?
        var transformEnabled: Bool = false
        var onTransformBegan: ((SurfaceHit) -> Void)?
        var onTransformChanged: ((Float, Float) -> Void)?
        var onTransformEnded: (() -> Void)?
        var onEmptyTap: (() -> Void)?
        var gizmoCenter: SIMD3<Float>?
        var gizmoAxisLength: Float = 1.0
        var onGizmoDragBegan: ((SIMD3<Float>) -> Void)?
        private var isTransforming = false
        /// Pencil = SIEMPRE herramienta, nunca orbita (BLUEPRINT S1).
        /// Se captura en shouldReceive porque los recognizers no exponen el touch.
        private var lastTouchWasPencil = false
        /// Presión del trazo (pencil: force real; dedo: 1.0) → SculptPoint.pressure.
        private var strokePressure: Float = 1.0
        
        private var lastPanLocation: CGPoint = .zero
        private var orbitSpherical: (theta: Float, phi: Float, radius: Float) = (0, .pi / 4, 5.0)
        private var panTarget: SIMD3<Float> = .zero
        private var isOrbiting = false
        private var isPanning = false
        private var isSculpting = false
        private var currentBrush: BrushType = .grab
        private var lastSculptHit: SIMD3<Float>? = nil
        
        init(scene: Binding<Scene3D>, strokes: Binding<[BrushStroke]>,
             renderer: SatinRenderer,
             onTouch3D: ((SIMD3<Float>, SIMD3<Float>) -> Void)?,
             onObjectSelected: ((Int?) -> Void)?,
             onSculptStroke: ((SculptPoint) -> Void)?,
             animationEngine: AnimationEngine? = nil) {
            self._scene = scene
            self._strokes = strokes
            self.renderer = renderer
            self.onTouch3D = onTouch3D
            self.onObjectSelected = onObjectSelected
            self.onSculptStroke = onSculptStroke
            self.animationEngine = animationEngine
        }
        
        // MARK: - Gesture Setup
        
        func setupGestures(_ view: MTKView) {
            let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
            pan.delegate = self
            pan.maximumNumberOfTouches = 2
            view.addGestureRecognizer(pan)
            
            let pinch = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
            pinch.delegate = self
            view.addGestureRecognizer(pinch)

            // Tercer eje de cámara (como Shapr3D): torcer con 2 dedos = ROLL
            // (girar la vista alrededor del eje de mirada).
            let roll = UIRotationGestureRecognizer(target: self, action: #selector(handleRoll(_:)))
            roll.delegate = self
            view.addGestureRecognizer(roll)
            
            let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
            tap.delegate = self
            view.addGestureRecognizer(tap)

            // Gestos globales (BLUEPRINT S9/N7). El tap simple NO espera al doble
            // (require(toFail:) metería ~300ms de latencia en cada selección — Shapr3D
            // selecciona instantáneo); doble tap = seleccionar y encuadrar, inofensivo.
            let undoTap = UITapGestureRecognizer(target: self, action: #selector(handleUndoTap(_:)))
            undoTap.numberOfTouchesRequired = 2
            undoTap.delegate = self
            view.addGestureRecognizer(undoTap)

            let redoTap = UITapGestureRecognizer(target: self, action: #selector(handleRedoTap(_:)))
            redoTap.numberOfTouchesRequired = 3
            redoTap.delegate = self
            view.addGestureRecognizer(redoTap)

            let doubleTap = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap(_:)))
            doubleTap.numberOfTapsRequired = 2
            doubleTap.delegate = self
            view.addGestureRecognizer(doubleTap)
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
            // Los taps de undo/redo (2/3 dedos) NO se reconocen en simultáneo con
            // pan/pinch: el inicio de un zoom contaba también como tap → deshacer
            // SILENCIOSO que "borraba" el trabajo (feedback de device: 'cuando
            // muevo desaparece lo que había hecho').
            func isMultiTouchTap(_ g: UIGestureRecognizer) -> Bool {
                (g as? UITapGestureRecognizer)?.numberOfTouchesRequired ?? 0 >= 2
            }
            func isCameraGesture(_ g: UIGestureRecognizer) -> Bool {
                g is UIPinchGestureRecognizer || g is UIPanGestureRecognizer
                    || g is UIRotationGestureRecognizer
            }
            if isMultiTouchTap(gestureRecognizer) && isCameraGesture(other) { return false }
            if isMultiTouchTap(other) && isCameraGesture(gestureRecognizer) { return false }
            return true
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
            lastTouchWasPencil = (touch.type == .pencil)
            if lastTouchWasPencil, touch.maximumPossibleForce > 0 {
                // force llega a 0 al inicio del toque: clamp para no matar el trazo.
                strokePressure = max(0.2, Float(touch.force / touch.maximumPossibleForce))
                if touch.force == 0 { strokePressure = 1.0 }
            } else {
                strokePressure = 1.0
            }
            return true
        }
        
        // MARK: - Gesture Handlers

        /// Sincroniza el estado esférico de órbita desde la cámara REAL de la escena.
        /// Sin esto, el primer gesto "salta" a un estado viejo (la cámara pudo moverse
        /// por el ViewCube, resetView o la posición inicial) — feedback de device:
        /// "el desplazamiento queda como fijo en el punto anterior".
        private func syncOrbitFromCamera() {
            let cam = scene.camera
            let offset = cam.position - cam.target
            let r = simd_length(offset)
            guard r > 0.0001 else { return }
            orbitSpherical.radius = r
            orbitSpherical.phi = acos(max(-1, min(1, offset.y / r)))
            orbitSpherical.theta = atan2(offset.z, offset.x)
            panTarget = cam.target
        }

        @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
            let location = gesture.location(in: gesture.view)
            let translation = gesture.translation(in: gesture.view)

            switch gesture.state {
            case .began:
                lastPanLocation = location
                syncOrbitFromCamera()
                let singleFinger = (gesture.numberOfTouches == 1)
                // Router del contrato de gestos: 1 dedo sobre geometría = herramienta
                // (sculpt), sobre vacío = orbitar. El hitTest usa ScenePicker (único
                // camino de picking; ignora overlays "__" como el highlight de cara).
                if singleFinger && transformEnabled, let view = gesture.view {
                    // Prioridad: manija del gizmo → cuerpo → vacío (orbitar).
                    if let axis = gizmoAxisHit(at: location, in: view) {
                        isTransforming = true
                        onGizmoDragBegan?(axis)
                    } else {
                        let ray = CameraRay.from(screenPoint: location, viewSize: view.bounds.size,
                                                 camera: scene.camera)
                        if let hit = ScenePicker.hitTest(models: scene.models, ray: ray) {
                            isTransforming = true
                            onTransformBegan?(hit)
                        } else if !lastTouchWasPencil {
                            isOrbiting = true
                        }
                    }
                } else if singleFinger && sculptEnabled && renderer.sculptEngine != nil {
                    if let hit = sculptHit(at: location, in: gesture.view) {
                        isSculpting = true
                        lastSculptHit = hit.position
                        // Seed first SculptPoint (no drag on first touch)
                        let point = SculptPoint(
                            position: hit.position,
                            normal: hit.normal,
                            pressure: strokePressure,
                            dragDelta: .zero
                        )
                        renderer.sculptEngine?.pendingStrokes.append(point)
                        renderer.brushCursorPosition = hit.position
                        renderer.brushCursorRadius = renderer.sculptEngine?.radius ?? 0.05
                        onSculptStroke?(point)
                    } else if !lastTouchWasPencil {
                        // Pencil nunca orbita (S1): dedo en vacío = cámara, pencil = nada.
                        isOrbiting = true
                    }
                } else if singleFinger {
                    if !lastTouchWasPencil { isOrbiting = true }
                } else {
                    isPanning = true
                }

            case .changed:
                let dx = Float(translation.x) * 0.005
                let dy = Float(translation.y) * 0.005

                if isTransforming {
                    onTransformChanged?(Float(translation.x), Float(translation.y))
                } else if isSculpting {
                    if let hit = sculptHit(at: location, in: gesture.view) {
                        let prev = lastSculptHit ?? hit.position
                        let dragDelta = hit.position - prev
                        lastSculptHit = hit.position
                        let point = SculptPoint(
                            position: hit.position,
                            normal: hit.normal,
                            pressure: strokePressure,
                            dragDelta: dragDelta
                        )
                        renderer.sculptEngine?.pendingStrokes.append(point)
                        renderer.brushCursorPosition = hit.position
                        renderer.brushCursorRadius = renderer.sculptEngine?.radius ?? 0.05
                        onSculptStroke?(point)
                    }
                } else if isOrbiting {
                    orbitSpherical.theta += dx
                    orbitSpherical.phi -= dy
                    orbitSpherical.phi = max(0.1, min(.pi - 0.1, orbitSpherical.phi))
                    updateCameraOrbit()
                } else if isPanning {
                    // Pan relativo a la CÁMARA (right/up del punto de vista actual).
                    // Antes paneaba en ejes del mundo: tras orbitar, el arrastre se
                    // sentía "desde donde estaba antes" (feedback de device).
                    let cam = scene.camera
                    let forward = simd_normalize(cam.target - cam.position)
                    let right = simd_normalize(simd_cross(forward, cam.up))
                    let up = simd_cross(right, forward)
                    let scale = orbitSpherical.radius * 0.5
                    panTarget -= right * dx * scale
                    panTarget += up * dy * scale
                    updateCameraOrbit()
                }

                gesture.setTranslation(.zero, in: gesture.view)

            case .ended, .cancelled:
                if isTransforming { onTransformEnded?() }
                isTransforming = false
                isOrbiting = false
                isPanning = false
                isSculpting = false
                lastSculptHit = nil
                renderer.brushCursorPosition = nil

            default: break
            }
        }
        
        @objc private func handlePinch(_ gesture: UIPinchGestureRecognizer) {
            let scale = Float(gesture.scale)
            switch gesture.state {
            case .began:
                syncOrbitFromCamera()
            case .changed:
                orbitSpherical.radius /= max(0.1, scale)
                orbitSpherical.radius = max(0.5, min(50.0, orbitSpherical.radius))
                updateCameraOrbit()
                gesture.scale = 1.0
            default: break
            }
        }
        
        /// Shapr3D signature: two-finger vertical drag = extrude, horizontal = taper angle.
        /// Works when a sketch profile is selected in CAD mode.
        private var isExtruding: Bool = false
        private var extrudeBaseDistance: Float = 0
        
        @objc private func handlePinchExtrude(_ gesture: UIPanGestureRecognizer) {
            guard gesture.numberOfTouches >= 2 else { return }
            let translation = gesture.translation(in: gesture.view)
            
            switch gesture.state {
            case .began:
                isExtruding = true
                extrudeBaseDistance = 0
            case .changed:
                let distance = Float(-translation.y) * 0.2  // Up = extrude up
                let taper = Float(translation.x) * 0.05      // Side = taper angle
                onPinchExtrude?(distance, taper)
            case .ended, .cancelled:
                isExtruding = false
            default: break
            }
        }

        @objc private func handleRoll(_ gesture: UIRotationGestureRecognizer) {
            switch gesture.state {
            case .changed:
                let cam = scene.camera
                let forward = simd_normalize(cam.target - cam.position)
                let q = simd_quatf(angle: Float(-gesture.rotation), axis: forward)
                scene.camera.up = simd_normalize(q.act(cam.up))
                gesture.rotation = 0
            default: break
            }
        }

        @objc private func handleUndoTap(_ gesture: UITapGestureRecognizer) {
            onUndoGesture?()
        }

        @objc private func handleRedoTap(_ gesture: UITapGestureRecognizer) {
            onRedoGesture?()
        }

        @objc private func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
            onFrameGesture?()
        }

        @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
            let location = gesture.location(in: gesture.view)
            guard let view = gesture.view as? MTKView else { return }

            let ray = CameraRay.from(screenPoint: location, viewSize: view.bounds.size,
                                     camera: scene.camera)
            let hit = ScenePicker.hitTest(models: scene.models, ray: ray)

            onObjectSelected?(hit?.modelIndex)
            if let hit = hit {
                // Punto de impacto REAL (antes se pasaba model.position — bug de precisión)
                onTouch3D?(hit.position, ray.direction)
                onSurfaceHit?(hit)
            } else {
                onEmptyTap?()
            }
        }
        
        // MARK: - Gizmo (hit-test en PANTALLA: robusto para manijas finas)

        /// Proyecta un punto de mundo a coordenadas de pantalla (puntos).
        private func projectToScreen(_ p: SIMD3<Float>, in view: UIView) -> CGPoint? {
            let size = view.bounds.size
            let aspect = Float(size.width / max(size.height, 1))
            let vm = SatinRenderer.viewMatrix(for: scene.camera)
            let pm = SatinRenderer.projectionMatrix(for: scene.camera, aspect: aspect)
            let eye = vm * SIMD4<Float>(p.x, p.y, p.z, 1)
            let clip = pm * eye
            guard clip.w > 0 else { return nil }   // detrás de la cámara
            let ndc = SIMD2<Float>(clip.x / clip.w, clip.y / clip.w)
            return CGPoint(x: CGFloat((ndc.x + 1) * 0.5) * size.width,
                           y: CGFloat((1 - ndc.y) * 0.5) * size.height)
        }

        /// Eje del gizmo bajo el toque (distancia 2D al segmento centro→punta < 34pt).
        private func gizmoAxisHit(at location: CGPoint, in view: UIView) -> SIMD3<Float>? {
            guard let center = gizmoCenter,
                  let c2 = projectToScreen(center, in: view) else { return nil }
            let axes: [SIMD3<Float>] = [SIMD3<Float>(1, 0, 0), SIMD3<Float>(0, 1, 0), SIMD3<Float>(0, 0, 1)]
            var best: (axis: SIMD3<Float>, dist: CGFloat)?
            for axis in axes {
                guard let t2 = projectToScreen(center + axis * gizmoAxisLength, in: view) else { continue }
                let d = distanceToSegment(location, a: c2, b: t2)
                if d < 34, d < (best?.dist ?? .greatestFiniteMagnitude) {
                    best = (axis, d)
                }
            }
            return best?.axis
        }

        private func distanceToSegment(_ p: CGPoint, a: CGPoint, b: CGPoint) -> CGFloat {
            let ab = CGPoint(x: b.x - a.x, y: b.y - a.y)
            let ap = CGPoint(x: p.x - a.x, y: p.y - a.y)
            let len2 = ab.x * ab.x + ab.y * ab.y
            let t = len2 > 0 ? max(0, min(1, (ap.x * ab.x + ap.y * ab.y) / len2)) : 0
            let proj = CGPoint(x: a.x + ab.x * t, y: a.y + ab.y * t)
            return hypot(p.x - proj.x, p.y - proj.y)
        }

        // MARK: - Sculpt Raycast

        /// Hit de superficie para sculpt vía el picking unificado (ScenePicker).
        /// A diferencia del raycast antiguo, ignora overlays "__" (highlight de cara).
        private func sculptHit(at screenPoint: CGPoint, in view: UIView?) -> (position: SIMD3<Float>, normal: SIMD3<Float>)? {
            guard let view = view else { return nil }
            let ray = CameraRay.from(screenPoint: screenPoint, viewSize: view.bounds.size,
                                     camera: scene.camera)
            guard let hit = ScenePicker.hitTest(models: scene.models, ray: ray) else { return nil }
            return (hit.position, hit.normal)
        }

        // MARK: - Camera

        private func updateCameraOrbit() {
            let theta = orbitSpherical.theta
            let phi = orbitSpherical.phi
            let r = orbitSpherical.radius
            
            let x = panTarget.x + r * sin(phi) * cos(theta)
            let y = panTarget.y + r * cos(phi)
            let z = panTarget.z + r * sin(phi) * sin(theta)
            
            scene.camera.position = SIMD3<Float>(x, y, z)
            scene.camera.target = panTarget
        }
        
        // MARK: - MTKViewDelegate
        
        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
            let aspect = Float(size.width / max(size.height, 1))
            renderer.aspectRatio = aspect
        }
        
        func draw(in view: MTKView) {
            renderer.updateScene(scene)
            renderer.updateAnimation()
            renderer.render(in: view)
        }
    }
}
