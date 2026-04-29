import Foundation
import simd
import QuartzCore

// MARK: - Keyframe
struct Keyframe<T> {
    let time: Float
    let value: T
    let easing: Easing
    
    init(time: Float, value: T, easing: Easing = .linear) {
        self.time = time
        self.value = value
        self.easing = easing
    }
}

// MARK: - Easing
enum Easing {
    case linear
    case easeInQuad
    case easeOutQuad
    case easeInOutQuad
    case easeInCubic
    case easeOutCubic
    case easeInOutCubic
    
    func apply(_ t: Float) -> Float {
        switch self {
        case .linear: return t
        case .easeInQuad: return t * t
        case .easeOutQuad: return t * (2 - t)
        case .easeInOutQuad: return t < 0.5 ? 2 * t * t : -1 + (4 - 2 * t) * t
        case .easeInCubic: return t * t * t
        case .easeOutCubic: return (t - 1) * (t - 1) * (t - 1) + 1
        case .easeInOutCubic: return t < 0.5 ? 4 * t * t * t : (t - 1) * (2 * t - 2) * (2 * t - 2) + 1
        }
    }
}

// MARK: - AnimationClip
struct AnimationClip {
    let name: String
    let duration: Float
    var loop: Bool = false
    var positionFrames: [Keyframe<SIMD3<Float>>] = []
    var rotationFrames: [Keyframe<simd_quatf>] = []
    var scaleFrames: [Keyframe<SIMD3<Float>>] = []
    var targetModelName: String = ""
    
    init(name: String, duration: Float) {
        self.name = name
        self.duration = duration
    }
}

// MARK: - AnimationEngine
@MainActor
class AnimationEngine: ObservableObject {
    @Published var isPlaying = false
    @Published var currentTime: Float = 0
    @Published var selectedClipName: String = ""
    @Published var clips: [String: AnimationClip] = [:]
    
    @Published var keyframes: [KeyframeEntry] = []
    @Published var keyframeTypes: [String] = ["posicion", "rotacion", "escala"]
    
    struct KeyframeEntry: Identifiable {
        let id = UUID()
        var type: String
        var time: Float
        var modelName: String
    }
    
    func addKeyframe(type: String, time: Float, modelName: String) {
        let entry = KeyframeEntry(type: type, time: time, modelName: modelName)
        keyframes.append(entry)
        keyframes.sort { $0.time < $1.time }
    }
    
    func removeKeyframe(id: UUID) {
        keyframes.removeAll { $0.id == id }
    }
    
    private weak var appState: AppState?
    private var lastFrameTime: CFTimeInterval = 0
    private var displayLink: CADisplayLink?
    
    init(appState: AppState?) {
        self.appState = appState
    }
    
    deinit {
        stopDisplayLink()
    }
    
    // MARK: - Clip Management
    func registerClip(_ clip: AnimationClip) {
        clips[clip.name] = clip
    }
    
    func removeClip(named name: String) {
        clips.removeValue(forKey: name)
    }
    
    // MARK: - Playback Control
    func playClip(named name: String) {
        guard clips[name] != nil else { return }
        selectedClipName = name
        currentTime = 0
        isPlaying = true
        lastFrameTime = CACurrentMediaTime()
        startDisplayLink()
    }
    
    func stop() {
        isPlaying = false
        stopDisplayLink()
    }
    
    func pause() {
        isPlaying = false
        stopDisplayLink()
    }
    
    func resume() {
        isPlaying = true
        lastFrameTime = CACurrentMediaTime()
        startDisplayLink()
    }
    
    // MARK: - Update Scene (CORREGIDO: ahora recibe Scene3D como inout)
    func updateScene(_ scene: inout Scene3D, deltaTime: Float) {
        guard isPlaying, let clip = clips[selectedClipName] else { return }
        
        currentTime += deltaTime
        
        // Loop si el clip esta configurado para loop
        if currentTime >= clip.duration {
            if clip.loop {
                currentTime = currentTime.truncatingRemainder(dividingBy: clip.duration)
            } else {
                currentTime = clip.duration
                stop()
                return
            }
        }
        
        let t = currentTime / clip.duration
        
        // Actualizar posicion del modelo objetivo si hay keyframes de posicion
        if !clip.positionFrames.isEmpty {
            let interpolatedPos = interpolatePosition(frames: clip.positionFrames, time: t)
            if let modelIndex = scene.models.firstIndex(where: { $0.name == clip.targetModelName }) {
                scene.models[modelIndex].transform.position = interpolatedPos
            }
        }
        
        // Actualizar rotacion si hay keyframes de rotacion
        if !clip.rotationFrames.isEmpty {
            let interpolatedRot = interpolateRotation(frames: clip.rotationFrames, time: t)
            if let modelIndex = scene.models.firstIndex(where: { $0.name == clip.targetModelName }) {
                scene.models[modelIndex].transform.rotation = interpolatedRot
            }
        }
        
        // Actualizar escala si hay keyframes de escala
        if !clip.scaleFrames.isEmpty {
            let interpolatedScale = interpolateScale(frames: clip.scaleFrames, time: t)
            if let modelIndex = scene.models.firstIndex(where: { $0.name == clip.targetModelName }) {
                scene.models[modelIndex].transform.scale = interpolatedScale
            }
        }
    }
    
    // MARK: - Interpolacion de Keyframes
    private func interpolatePosition(frames: [Keyframe<SIMD3<Float>>], time: Float) -> SIMD3<Float> {
        guard frames.count > 1 else { return frames.first?.value ?? .zero }
        
        var prev = frames[0]
        var next = frames.last!
        
        for i in 1..<frames.count {
            if frames[i].time > time {
                next = frames[i]
                break
            }
            prev = frames[i]
        }
        
        let duration = next.time - prev.time
        guard duration > 0 else { return next.value }
        let localT = (time - prev.time) / duration
        let easedT = prev.easing.apply(localT)
        return simd_mix(prev.value, next.value, easedT)
    }
    
    private func interpolateRotation(frames: [Keyframe<simd_quatf>], time: Float) -> simd_quatf {
        guard frames.count > 1 else { return frames.first?.value ?? .init(real: 1, imag: .zero) }
        
        var prev = frames[0]
        var next = frames.last!
        
        for i in 1..<frames.count {
            if frames[i].time > time {
                next = frames[i]
                break
            }
            prev = frames[i]
        }
        
        let duration = next.time - prev.time
        guard duration > 0 else { return next.value }
        let localT = (time - prev.time) / duration
        let easedT = prev.easing.apply(localT)
        return simd_slerp(prev.value, next.value, easedT)
    }
    
    private func interpolateScale(frames: [Keyframe<SIMD3<Float>>], time: Float) -> SIMD3<Float> {
        guard frames.count > 1 else { return frames.first?.value ?? .init(repeating: 1) }
        
        var prev = frames[0]
        var next = frames.last!
        
        for i in 1..<frames.count {
            if frames[i].time > time {
                next = frames[i]
                break
            }
            prev = frames[i]
        }
        
        let duration = next.time - prev.time
        guard duration > 0 else { return next.value }
        let localT = (time - prev.time) / duration
        let easedT = prev.easing.apply(localT)
        return simd_mix(prev.value, next.value, easedT)
    }
    
    // MARK: - Display Link
    private func startDisplayLink() {
        stopDisplayLink()
        displayLink = CADisplayLink(target: self, selector: #selector(tick))
        displayLink?.add(to: .main, forMode: .common)
    }
    
    private func stopDisplayLink() {
        displayLink?.invalidate()
        displayLink = nil
    }
    
    @objc private func tick() {
        guard isPlaying else { return }
        let now = CACurrentMediaTime()
        let delta = Float(now - lastFrameTime)
        lastFrameTime = now
        
        // Llamar updateScene con la escena del appState
        if var scene = appState?.canvasVM.scene {
            // Hacemos una copia mutable, actualizamos y reasignamos
            updateScene(&scene, deltaTime: delta)
            appState?.canvasVM.scene = scene
        }
    }
}