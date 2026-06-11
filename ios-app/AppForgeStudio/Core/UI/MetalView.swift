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
    var metalBackground: UIColor = .darkGray
    
    func makeCoordinator() -> Coordinator {
        Coordinator(
            scene: $scene, strokes: $strokes,
            renderer: renderer, onTouch3D: onTouch3D,
            onObjectSelected: onObjectSelected,
            onSculptStroke: onSculptStroke,
            animationEngine: animationEngine
        )
    }
    
    func makeUIView(context: Context) -> MTKView {
        let v = MTKView()
        v.device = MTLCreateSystemDefaultDevice()
        v.delegate = context.coordinator
        v.backgroundColor = metalBackground
        v.enableSetNeedsDisplay = true
        v.isPaused = false
        v.isMultipleTouchEnabled = true
        
        renderer.updateScene(scene)
        context.coordinator.setupGestures(v)
        
        return v
    }
    
    func updateUIView(_ uiView: MTKView, context: Context) {
        renderer.updateScene(scene)
        renderer.animationEngine = animationEngine
        renderer.playbackController = playbackController
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
        var onPinchExtrude: ((Float, Float) -> Void)?  // (distance, taper)
        
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
            
            let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
            tap.delegate = self
            view.addGestureRecognizer(tap)
        }
        
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
            true
        }
        
        // MARK: - Gesture Handlers
        
        @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
            let location = gesture.location(in: gesture.view)
            let translation = gesture.translation(in: gesture.view)

            switch gesture.state {
            case .began:
                lastPanLocation = location
                let singleFinger = (gesture.numberOfTouches == 1)
                // Sculpt mode: single finger on mesh → sculpt; otherwise orbit
                if singleFinger && renderer.sculptEngine != nil {
                    // Attempt raycast; if we hit a mesh, enter sculpt mode
                    if let hit = raycastForSculpt(at: location, in: gesture.view) {
                        isSculpting = true
                        lastSculptHit = hit.position
                        // Seed first SculptPoint (no drag on first touch)
                        let point = SculptPoint(
                            position: hit.position,
                            normal: hit.normal,
                            pressure: 1.0,
                            dragDelta: .zero
                        )
                        renderer.sculptEngine?.pendingStrokes.append(point)
                        renderer.brushCursorPosition = hit.position
                        renderer.brushCursorRadius = renderer.sculptEngine?.radius ?? 0.05
                        onSculptStroke?(point)
                    } else {
                        isOrbiting = true
                    }
                } else if singleFinger {
                    isOrbiting = true
                } else {
                    isPanning = true
                }

            case .changed:
                let dx = Float(translation.x) * 0.005
                let dy = Float(translation.y) * 0.005

                if isSculpting {
                    if let hit = raycastForSculpt(at: location, in: gesture.view) {
                        let prev = lastSculptHit ?? hit.position
                        let dragDelta = hit.position - prev
                        lastSculptHit = hit.position
                        let point = SculptPoint(
                            position: hit.position,
                            normal: hit.normal,
                            pressure: 1.0,
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
                    panTarget.x -= dx * orbitSpherical.radius * 0.5
                    panTarget.y += dy * orbitSpherical.radius * 0.5
                    updateCameraOrbit()
                }

                gesture.setTranslation(.zero, in: gesture.view)

            case .ended, .cancelled:
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
        
        @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
            let location = gesture.location(in: gesture.view)
            guard let view = gesture.view as? MTKView else { return }
            let size = view.bounds.size
            
            let rayOrigin = scene.camera.position
            let aspect = Float(size.width / max(size.height, 1))
            let ndc = SIMD2<Float>(
                (2.0 * Float(location.x) / Float(size.width) - 1.0) * aspect,
                1.0 - 2.0 * Float(location.y) / Float(size.height)
            )
            let fovRad = scene.camera.fov * .pi / 180
            let halfH = tan(fovRad * 0.5)
            let halfW = halfH * aspect
            
            let forward = simd_normalize(scene.camera.target - scene.camera.position)
            let right = simd_normalize(simd_cross(forward, scene.camera.up))
            let up = simd_cross(right, forward)
            
            let rayDir = simd_normalize(forward + right * ndc.x * halfW + up * ndc.y * halfH)
            
            var closestDist: Float = .greatestFiniteMagnitude
            var closestIndex: Int?
            
            for (i, model) in scene.models.enumerated() {
                for mesh in model.meshes {
                    for j in stride(from: 0, to: mesh.indices.count, by: 3) {
                        guard j + 2 < mesh.indices.count else { break }
                        let i0 = Int(mesh.indices[j])
                        let i1 = Int(mesh.indices[j+1])
                        let i2 = Int(mesh.indices[j+2])
                        guard i0 < mesh.vertices.count, i1 < mesh.vertices.count, i2 < mesh.vertices.count else { continue }
                        if let hit = rayTriangleIntersect(
                            rayOrigin: rayOrigin, rayDir: rayDir,
                            v0: mesh.vertices[i0].position,
                            v1: mesh.vertices[i1].position,
                            v2: mesh.vertices[i2].position
                        ) {
                            let dist = simd_distance(rayOrigin, hit)
                            if dist < closestDist {
                                closestDist = dist
                                closestIndex = i
                            }
                        }
                    }
                }
            }
            
            onObjectSelected?(closestIndex)
            if let hitPos = closestIndex != nil ? scene.models[closestIndex!].position : nil {
                onTouch3D?(hitPos, rayDir)
            }
        }
        
        // MARK: - Sculpt Raycast

        /// Raycasts from the camera through the given screen point against all scene models.
        /// Returns the closest hit position and surface normal, or nil if no mesh is intersected.
        private func raycastForSculpt(at screenPoint: CGPoint, in view: UIView?) -> (position: SIMD3<Float>, normal: SIMD3<Float>)? {
            guard let view = view else { return nil }
            let size = view.bounds.size

            let rayOrigin = scene.camera.position
            let aspect = Float(size.width / max(size.height, 1))
            let ndc = SIMD2<Float>(
                (2.0 * Float(screenPoint.x) / Float(size.width) - 1.0) * aspect,
                1.0 - 2.0 * Float(screenPoint.y) / Float(size.height)
            )
            let fovRad = scene.camera.fov * .pi / 180
            let halfH = tan(fovRad * 0.5)
            let halfW = halfH * aspect

            let forward = simd_normalize(scene.camera.target - scene.camera.position)
            let right = simd_normalize(simd_cross(forward, scene.camera.up))
            let up = simd_cross(right, forward)
            let rayDir = simd_normalize(forward + right * ndc.x * halfW + up * ndc.y * halfH)

            var closestDist: Float = .greatestFiniteMagnitude
            var bestHit: (position: SIMD3<Float>, normal: SIMD3<Float>)?

            for model in scene.models {
                for mesh in model.meshes {
                    for j in stride(from: 0, to: mesh.indices.count, by: 3) {
                        guard j + 2 < mesh.indices.count else { break }
                        let i0 = Int(mesh.indices[j])
                        let i1 = Int(mesh.indices[j+1])
                        let i2 = Int(mesh.indices[j+2])
                        guard i0 < mesh.vertices.count, i1 < mesh.vertices.count, i2 < mesh.vertices.count else { continue }
                        let v0 = mesh.vertices[i0].position
                        let v1 = mesh.vertices[i1].position
                        let v2 = mesh.vertices[i2].position
                        if let hit = rayTriangleIntersect(
                            rayOrigin: rayOrigin, rayDir: rayDir,
                            v0: v0, v1: v1, v2: v2
                        ) {
                            let dist = simd_distance(rayOrigin, hit)
                            if dist < closestDist {
                                closestDist = dist
                                // Compute face normal at hit point
                                let edge1 = v1 - v0
                                let edge2 = v2 - v0
                                let faceNormal = simd_normalize(simd_cross(edge1, edge2))
                                // Use vertex normal interpolation for smoother results
                                let n0 = mesh.vertices[i0].normal
                                let n1 = mesh.vertices[i1].normal
                                let n2 = mesh.vertices[i2].normal
                                let interpolatedNormal = simd_normalize(n0 + n1 + n2)
                                let hitNormal = simd_length(interpolatedNormal) > 0.001
                                    ? interpolatedNormal
                                    : faceNormal
                                bestHit = (hit, hitNormal)
                            }
                        }
                    }
                }
            }
            return bestHit
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
