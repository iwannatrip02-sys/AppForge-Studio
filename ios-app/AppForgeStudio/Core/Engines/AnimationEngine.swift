import Foundation
import simd
import Combine

// MARK: - Keyframe
struct Keyframe {
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

    static func lerp(from a: Keyframe, to b: Keyframe, t: Float) -> Keyframe {
        let clampedT = max(0, min(1, (t - a.time) / (b.time - a.time)))
        return Keyframe(
            time: t,
            translation: simd_mix(a.translation, b.translation, .init(repeating: clampedT)),
            rotation: simd_slerp(a.rotation, b.rotation, clampedT),
            scale: simd_mix(a.scale, b.scale, .init(repeating: clampedT))
        )
    }
}

// MARK: - Clip
struct Clip {
    let name: String
    let duration: Float
    let keyframes: [String: [Keyframe]]
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
            var next = kfs.last!
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
                let interp = Keyframe.lerp(from: prev, to: next, t: clampedTime)
                result[nodeID] = interp.transform
            }
        }
        return result
    }
}

// MARK: - AnimationEngine
class AnimationEngine: ObservableObject {
    @Published var isPlaying: Bool = false
    @Published var currentTime: Float = 0
    @Published var currentClipIndex: Int = 0
    @Published var currentClipDuration: Float = 0

    var clips: [Clip] = []
    var loop: Bool = true

    var currentClip: Clip? {
        guard clips.indices.contains(currentClipIndex) else { return nil }
        return clips[currentClipIndex]
    }

    init() {
        clips.append(Clip(name: "Default", duration: 2.0, keyframes: [:]))
        currentClipDuration = clips[0].duration
    }

    func addClip(_ clip: Clip) { clips.append(clip) }

    func addKeyframe(nodeID: String, keyframe: Keyframe, clipIndex: Int = 0) {
        guard clips.indices.contains(clipIndex) else { return }
        var clip = clips[clipIndex]
        var kfs = clip.keyframes[nodeID] ?? []
        kfs.append(keyframe)
        kfs.sort { $0.time < $1.time }
        clip.keyframes[nodeID] = kfs
        clip.duration = max(clip.duration, keyframe.time)
        clips[clipIndex] = clip
        currentClipDuration = clip.duration
    }

    func togglePlayPause() {
        isPlaying.toggle()
        if isPlaying && currentTime >= currentClipDuration { currentTime = 0 }
    }

    func play() {
        isPlaying = true
        if currentTime >= currentClipDuration { currentTime = 0 }
    }

    func stop() {
        isPlaying = false
        currentTime = 0
    }

    func evaluateAnimation(deltaTime: Float) -> [String: simd_float4x4] {
        guard isPlaying, let clip = currentClip else { return [:] }
        currentTime += deltaTime
        if currentTime >= clip.duration {
            if loop { currentTime = 0 }
            else { currentTime = clip.duration; isPlaying = false }
        }
        return clip.evaluate(at: currentTime)
    }
}
