import Foundation
import simd
import QuartzCore
import Combine
import OSLog

extension simd_float4x4 {
    init(_ quat: simd_quatf) {
        self = simd_matrix4x4(quat)
    }
}

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
enum Easing: String, CaseIterable {
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

// MARK: - EasingCurve (UI-friendly wrapper)
enum EasingCurve: String, CaseIterable {
    case linear
    case easeInQuad
    case easeOutQuad
    case easeInOutQuad
    case easeInCubic
    case easeOutCubic
    case easeInOutCubic

    var icon: String {
        switch self {
        case .linear: return "line.diagonal"
        case .easeInQuad: return "arrow.up.right.circle"
        case .easeOutQuad: return "arrow.down.right.circle"
        case .easeInOutQuad: return "circle.circle"
        case .easeInCubic: return "arrow.up.right.square"
        case .easeOutCubic: return "arrow.down.right.square"
        case .easeInOutCubic: return "square.circle"
        }
    }

    var easing: Easing {
        switch self {
        case .linear: return .linear
        case .easeInQuad: return .easeInQuad
        case .easeOutQuad: return .easeOutQuad
        case .easeInOutQuad: return .easeInOutQuad
        case .easeInCubic: return .easeInCubic
        case .easeOutCubic: return .easeOutCubic
        case .easeInOutCubic: return .easeInOutCubic
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
    var morphFrames: [String: [Keyframe<Float>]] = [:]
    var targetModelName: String = ""

    init(name: String, duration: Float) {
        self.name = name
        self.duration = duration
    }
}

// MARK: - Legacy Keyframe (non-generic, for backward compatibility)
struct LegacyKeyframe {
    let time: Float
    let translation: SIMD3<Float>
    let rotation: simd_quatf
    let scale: SIMD3<Float>

    init(time: Float = 0,
         translation: SIMD3<Float> = .zero,
         rotation: simd_quatf = simd_quatf(real: 1, imag: .zero),
         scale: SIMD3<Float> = SIMD3<Float>(1, 1, 1))
    {
        self.time = time
        self.translation = translation
        self.rotation = rotation
        self.scale = scale
    }

    var transform: simd_float4x4 {
        let T = simd_float4x4(
            SIMD4<Float>(1, 0, 0, 0),
            SIMD4<Float>(0, 1, 0, 0),
            SIMD4<Float>(0, 0, 1, 0),
            SIMD4<Float>(translation.x, translation.y, translation.z, 1)
        )
        let R = simd_float4x4(rotation)
        let S = simd_float4x4(
            SIMD4<Float>(scale.x, 0, 0, 0),
            SIMD4<Float>(0, scale.y, 0, 0),
            SIMD4<Float>(0, 0, scale.z, 0),
            SIMD4<Float>(0, 0, 0, 1)
        )
        return T * R * S
    }

    static func lerp(from a: LegacyKeyframe, to b: LegacyKeyframe, t: Float) -> LegacyKeyframe {
        let clampedT = max(0, min(1, (t - a.time) / (b.time - a.time)))
        return LegacyKeyframe(
            time: t,
            translation: simd_mix(a.translation, b.translation, .init(repeating: clampedT)),
            rotation: simd_slerp(a.rotation, b.rotation, clampedT),
            scale: simd_mix(a.scale, b.scale, .init(repeating: clampedT))
        )
    }
}

// MARK: - Legacy Clip (non-generic, for backward compatibility)
struct LegacyClip {
    let name: String
    let duration: Float
    let keyframes: [String: [LegacyKeyframe]]
    var loop: Bool = true

    func evaluate(at time: Float) -> [String: simd_float4x4] {
        var result: [String: simd_float4x4] = [:]
        let clampedTime = duration > 0 ? max(0, min(time, duration)) : 0
        for (nodeID, kfs) in keyframes {
            guard kfs.count >= 2 else {
                result[nodeID] = kfs.first?.transform ?? matrix_identity_float4x4
                continue
            }
            var prev = kfs[0]
            guard let next = kfs.last else { continue }
            for i in 0..<(kfs.count - 1) {
                if clampedTime >= kfs[i].time && clampedTime <= kfs[i+1].time {
                    prev = kfs[i]
                    next = kfs[i+1]
                    break
                }
            }
            if next.time == prev.time {
                result[nodeID] = prev.transform
            } else {
                let interp = LegacyKeyframe.lerp(from: prev, to: next, t: clampedTime)
                result[nodeID] = interp.transform
            }
        }
        return result
    }
}

// MARK: - AnimationEngine
@MainActor
class AnimationEngine: ObservableObject {
    private let logger = Logger(subsystem: "com.appforgestudio", category: "AnimationEngine")

    @Published var isPlaying = false
    @Published var currentTime: Float = 0
    @Published var selectedClipName: String = ""
    @Published var clips: [String: AnimationClip] = [:]

    @Published var keyframes: [KeyframeEntry] = []
    @Published var keyframeTypes: [String] = ["posicion", "rotacion", "escala"]

    @Published var currentTransforms: [String: simd_float4x4] = [:]

    var currentClipDuration: Float {
        clips[selectedClipName]?.duration ?? 5.0
    }

    // Legacy support
    var currentClipIndex: Int = 0
    var legacyClips: [LegacyClip] = []
    var loop: Bool = true

    struct KeyframeEntry: Identifiable {
        let id = UUID()
        var type: String
        var time: Float
        var modelName: String = ""
        var easing: String = "linear"
        var positionValue: SIMD3<Float> = .zero
        var rotationValue: simd_quatf = simd_quatf(ix: 0, iy: 0, iz: 0, r: 1)
        var scaleValue: SIMD3<Float> = SIMD3<Float>(1, 1, 1)

        var easingEnum: Easing {
            Easing(rawValue: easing) ?? .linear
        }
    }

    var onFrame: ((Float, [String: simd_float4x4]) -> Void)?
    var onFrameTick: (() -> Void)?
    var onMorphFrame: ((Float, [String: Float]) -> Void)?

    init() {}

    convenience init(appState: Any) {
        self.init()
    }

    func play() {
        isPlaying = true
    }

    func pause() {
        isPlaying = false
    }

    func stop() {
        isPlaying = false
        currentTime = 0
    }

    func togglePlayPause() {
        if isPlaying {
            pause()
        } else {
            play()
        }
    }

    func seek(to time: Float) {
        let duration = currentClipDuration
        currentTime = max(0, min(time, duration))
        let transforms = evaluate(at: currentTime)
        currentTransforms = transforms
        onFrame?(currentTime, transforms)
    }

    func registerClip(_ clip: AnimationClip) {
        clips[clip.name] = clip
    }

    func addKeyframe(modelName: String, type: String, time: Float) {
        let entry = KeyframeEntry(type: type, time: time, modelName: modelName)
        keyframes.append(entry)
        updateClipsFromKeyframes()
    }

    func addKeyframe(type: String, time: Float, modelName: String) {
        addKeyframe(modelName: modelName, type: type, time: time)
    }

    func removeKeyframe(at index: Int) {
        guard index >= 0, index < keyframes.count else { return }
        keyframes.remove(at: index)
        updateClipsFromKeyframes()
    }

    func removeKeyframe(at time: Float) {
        keyframes.removeAll { abs($0.time - time) < 0.001 }
        updateClipsFromKeyframes()
    }

    func moveKeyframe(id: UUID, to newTime: Float) {
        guard let index = keyframes.firstIndex(where: { $0.id == id }) else { return }
        keyframes[index].time = max(0, min(newTime, currentClipDuration))
        updateClipsFromKeyframes()
    }

    private func updateClipsFromKeyframes() {
        guard !selectedClipName.isEmpty else { return }
        var clip = clips[selectedClipName] ?? AnimationClip(name: selectedClipName, duration: 5.0)
        clip.positionFrames = []
        clip.rotationFrames = []
        clip.scaleFrames = []

        let modelKfs = keyframes.filter { $0.modelName == selectedClipName }
        for kf in modelKfs {
            switch kf.type {
            case "posicion":
                clip.positionFrames.append(Keyframe(time: kf.time, value: kf.positionValue, easing: kf.easingEnum))
            case "rotacion":
                clip.rotationFrames.append(Keyframe(time: kf.time, value: kf.rotationValue, easing: kf.easingEnum))
            case "escala":
                clip.scaleFrames.append(Keyframe(time: kf.time, value: kf.scaleValue, easing: kf.easingEnum))
            default:
                break
            }
        }
        clips[selectedClipName] = clip
    }

    func evaluateAnimation(deltaTime: Float) -> [String: simd_float4x4] {
        let duration = currentClipDuration
        guard duration > 0, isPlaying else { return [:] }

        var newTime = currentTime + deltaTime

        if let clip = clips[selectedClipName], clip.loop {
            newTime = newTime.truncatingRemainder(dividingBy: duration)
            if newTime < 0 { newTime += duration }
        } else if newTime >= duration {
            newTime = duration
            isPlaying = false
        } else {
            newTime = max(0, newTime)
        }

        currentTime = newTime
        let transforms = evaluate(at: newTime)
        currentTransforms = transforms
        onFrame?(currentTime, transforms)
        onFrameTick?()
        return transforms
    }

    func evaluate(at time: Float) -> [String: simd_float4x4] {
        var result: [String: simd_float4x4] = [:]

        let relevantKeyframes: [KeyframeEntry]
        if !selectedClipName.isEmpty {
            relevantKeyframes = keyframes.filter { $0.modelName == selectedClipName }
        } else {
            relevantKeyframes = keyframes
        }

        let groups = Dictionary(grouping: relevantKeyframes) { $0.modelName }

        for (modelName, entries) in groups {
            let positionKeys = entries.filter { $0.type == "posicion" }.sorted { $0.time < $1.time }
            let rotationKeys = entries.filter { $0.type == "rotacion" }.sorted { $0.time < $1.time }
            let scaleKeys = entries.filter { $0.type == "escala" }.sorted { $0.time < $1.time }

            let pos = interpolatePosition(keys: positionKeys, at: time)
            let rot = interpolateRotation(keys: rotationKeys, at: time)
            let scale = interpolateScale(keys: scaleKeys, at: time)

            let translationMatrix = simd_float4x4.translation(pos)
            let rotationMatrix = simd_float4x4(rot)
            let scaleMatrix = simd_float4x4.scale(scale)

            let transform = translationMatrix * rotationMatrix * scaleMatrix
            result[modelName] = transform
        }

        if !selectedClipName.isEmpty, let clip = clips[selectedClipName] {
            var morphWeights: [String: Float] = [:]
            for (morphName, frames) in clip.morphFrames {
                let sorted = frames.sorted { $0.time < $1.time }
                guard sorted.count >= 2 else {
                    morphWeights[morphName] = sorted.first?.value ?? 0
                    continue
                }
                var prev = sorted[0]
                guard let next = sorted.last else { continue }
                for i in 0..<(sorted.count - 1) {
                    if time >= sorted[i].time && time <= sorted[i+1].time {
                        prev = sorted[i]
                        next = sorted[i+1]
                        break
                    }
                }
                if next.time == prev.time {
                    morphWeights[morphName] = prev.value
                } else {
                    let rawT = (time - prev.time) / (next.time - prev.time)
                    let t = prev.easing.apply(rawT)
                    morphWeights[morphName] = prev.value + (next.value - prev.value) * t
                }
            }
            if !morphWeights.isEmpty {
                onMorphFrame?(time, morphWeights)
            }
        }

        return result
    }

    // MARK: - Legacy API (from Core/Engines)

    func addLegacyClip(_ clip: LegacyClip) {
        legacyClips.append(clip)
    }

    func addLegacyKeyframe(nodeID: String, keyframe: LegacyKeyframe, clipIndex: Int = 0) {
        guard legacyClips.indices.contains(clipIndex) else { return }
        var clip = legacyClips[clipIndex]
        var kfs = clip.keyframes[nodeID] ?? []
        kfs.append(keyframe)
        kfs.sort { $0.time < $1.time }
        clip.keyframes[nodeID] = kfs
        clip.duration = max(clip.duration, keyframe.time)
        legacyClips[clipIndex] = clip
    }

    func evaluateLegacyAnimation(deltaTime: Float) -> [String: simd_float4x4] {
        guard isPlaying, legacyClips.indices.contains(currentClipIndex) else { return [:] }
        let clip = legacyClips[currentClipIndex]
        currentTime += deltaTime
        if currentTime >= clip.duration {
            if clip.loop { currentTime = 0 }
            else { currentTime = clip.duration; isPlaying = false }
        }
        return clip.evaluate(at: currentTime)
    }

    // MARK: - Interpolation

    private func interpolatePosition(keys: [KeyframeEntry], at time: Float) -> SIMD3<Float> {
        guard !keys.isEmpty else { return .zero }
        if keys.count == 1 { return keys[0].positionValue }

        var prev: KeyframeEntry?
        var next: KeyframeEntry?

        for key in keys {
            if key.time <= time { prev = key }
            if key.time >= time && next == nil { next = key }
        }

        guard let p = prev, let n = next else {
            if let p = prev {
                logger.warning("Position interpolation at time \(time): using last previous key at \(p.time)")
                return p.positionValue
            }
            if let n = next {
                logger.warning("Position interpolation at time \(time): using first next key at \(n.time)")
                return n.positionValue
            }
            logger.warning("Position interpolation at time \(time): no keys available, returning zero")
            return keys.last?.positionValue ?? .zero
        }

        if p.time == n.time {
            logger.warning("Zero division avoided in position interpolation at time \(time)")
            return p.positionValue
        }
        let rawT = (time - p.time) / (n.time - p.time)
        let t = p.easingEnum.apply(rawT)
        return simd_mix(p.positionValue, n.positionValue, t)
    }

    private func interpolateRotation(keys: [KeyframeEntry], at time: Float) -> simd_quatf {
        guard !keys.isEmpty else { return simd_quatf(ix: 0, iy: 0, iz: 0, r: 1) }
        if keys.count == 1 { return keys[0].rotationValue }

        var prev: KeyframeEntry?
        var next: KeyframeEntry?

        for key in keys {
            if key.time <= time { prev = key }
            if key.time >= time && next == nil { next = key }
        }

        guard let p = prev, let n = next else {
            if let p = prev {
                logger.warning("Rotation interpolation at time \(time): using last previous key at \(p.time)")
                return p.rotationValue
            }
            if let n = next {
                logger.warning("Rotation interpolation at time \(time): using first next key at \(n.time)")
                return n.rotationValue
            }
            logger.warning("Rotation interpolation at time \(time): no keys available, returning identity")
            return keys.last?.rotationValue ?? simd_quatf(ix: 0, iy: 0, iz: 0, r: 1)
        }

        if p.time == n.time {
            logger.warning("Zero division avoided in rotation interpolation at time \(time)")
            return p.rotationValue
        }
        let rawT = (time - p.time) / (n.time - p.time)
        let t = p.easingEnum.apply(rawT)
        return simd_slerp(p.rotationValue, n.rotationValue, t)
    }

    private func interpolateScale(keys: [KeyframeEntry], at time: Float) -> SIMD3<Float> {
        guard !keys.isEmpty else { return SIMD3<Float>(1, 1, 1) }
        if keys.count == 1 { return keys[0].scaleValue }

        var prev: KeyframeEntry?
        var next: KeyframeEntry?

        for key in keys {
            if key.time <= time { prev = key }
            if key.time >= time && next == nil { next = key }
        }

        guard let p = prev, let n = next else {
            if let p = prev {
                logger.warning("Scale interpolation at time \(time): using last previous key at \(p.time)")
                return p.scaleValue
            }
            if let n = next {
                logger.warning("Scale interpolation at time \(time): using first next key at \(n.time)")
                return n.scaleValue
            }
            logger.warning("Scale interpolation at time \(time): no keys available, returning identity")
            return keys.last?.scaleValue ?? SIMD3<Float>(1, 1, 1)
        }

        if p.time == n.time {
            logger.warning("Zero division avoided in scale interpolation at time \(time)")
            return p.scaleValue
        }
        let rawT = (time - p.time) / (n.time - p.time)
        let t = p.easingEnum.apply(rawT)
        return simd_mix(p.scaleValue, n.scaleValue, t)
    }

// MARK: - simd_float4x4 Extensions
private extension simd_float4x4 {
    static func translation(_ v: SIMD3<Float>) -> simd_float4x4 {
        var m = matrix_identity_float4x4
        m.columns.3 = SIMD4<Float>(v.x, v.y, v.z, 1)
        return m
    }

    static func scale(_ v: SIMD3<Float>) -> simd_float4x4 {
        var m = matrix_identity_float4x4
        m.columns.0.x = v.x
        m.columns.1.y = v.y
        m.columns.2.z = v.z
        return m
    }
}
}
