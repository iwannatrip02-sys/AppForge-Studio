import Foundation
import QuartzCore
import Combine

class AnimationPlaybackController: ObservableObject {
    @Published var currentTime: TimeInterval = 0
    @Published var isPlaying: Bool = false
    @Published var clips: [PlaybackClip] = []
    @Published var speedMultiplier: Float = 1.0

    private var displayLink: CADisplayLink?
    private var lastTimestamp: TimeInterval = 0
    private var animationEngine: AnimationEngine?
    var onFrameUpdate: ((TimeInterval) -> Void)?

    /// Duration of the active clip, or the engine's current clip duration as fallback.
    var duration: TimeInterval {
        if let active = clips.first(where: { $0.isActive }) {
            return active.duration
        }
        return animationEngine.map { TimeInterval($0.currentClipDuration) } ?? 10.0
    }

    /// Normalised progress 0...1.
    var progress: Double {
        let d = duration
        guard d > 0 else { return 0 }
        return (currentTime / d).clamped(to: 0...1)
    }

    /// Current playback speed (get/set).
    var playbackSpeed: Float {
        get { speedMultiplier }
        set { speedMultiplier = newValue.clamped(to: 0.1...10.0) }
    }

    /// Whether the active clip is set to loop.
    var isLooping: Bool {
        clips.first(where: { $0.isActive })?.loop ?? false
    }

    /// Human-readable name of the active clip, or a placeholder.
    var animationName: String {
        if let name = clips.first(where: { $0.isActive })?.name, !name.isEmpty {
            return name
        }
        if let engineName = animationEngine?.selectedClipName, !engineName.isEmpty {
            return engineName
        }
        return "Sin animacion"
    }

    /// Formatted current time (m:ss).
    var timeString: String {
        formatTime(currentTime)
    }

    /// Formatted duration (m:ss).
    var durationString: String {
        formatTime(duration)
    }

    init(animationEngine: AnimationEngine?) {
        self.animationEngine = animationEngine
    }

    // MARK: - Transport

    func play() {
        guard !isPlaying else { return }
        isPlaying = true
        lastTimestamp = CACurrentMediaTime()
        displayLink = CADisplayLink(target: self, selector: #selector(displayLinkTick))
        displayLink?.add(to: .main, forMode: .common)
        animationEngine?.play()
    }

    func pause() {
        isPlaying = false
        displayLink?.invalidate()
        displayLink = nil
        animationEngine?.pause()
    }

    func stop() {
        pause()
        currentTime = 0
        animationEngine?.stop()
        onFrameUpdate?(currentTime)
    }

    /// Toggle between play and pause.
    func togglePlayback() {
        if isPlaying { pause() } else { play() }
    }

    /// External frame-driven tick (called from SatinRenderer.updateAnimation).
    /// When this path is used, CADisplayLink is not activated.
    func tick(deltaTime: Float) {
        guard isPlaying else { return }
        let scaledDelta = TimeInterval(deltaTime * speedMultiplier)
        currentTime += scaledDelta

        if let active = clips.first(where: { $0.isActive }) {
            if currentTime >= active.duration {
                if active.loop {
                    currentTime = currentTime.truncatingRemainder(dividingBy: active.duration)
                } else {
                    currentTime = active.duration
                    pause()
                    onFrameUpdate?(currentTime)
                    return
                }
            }
        }

        animationEngine?.seek(to: Float(currentTime))
        onFrameUpdate?(currentTime)
    }

    // MARK: - Seek

    func seek(to time: TimeInterval) {
        let d = duration
        currentTime = max(0, min(time, d))
        animationEngine?.seek(to: Float(currentTime))
        onFrameUpdate?(currentTime)
    }

    // MARK: - Speed

    func setSpeed(_ speed: Float) {
        speedMultiplier = speed.clamped(to: 0.1...10.0)
    }

    // MARK: - Clip management

    func addClip(_ clip: PlaybackClip) {
        clips.append(clip)
    }

    func removeClip(_ clip: PlaybackClip) {
        clips.removeAll { $0.id == clip.id }
    }

    // MARK: - DisplayLink

    @objc private func displayLinkTick() {
        guard isPlaying else { return }
        let now = CACurrentMediaTime()
        let delta = now - lastTimestamp
        lastTimestamp = now

        let scaledDelta = delta * Double(speedMultiplier)
        currentTime += scaledDelta

        if let activeClip = clips.first(where: { $0.isActive }) {
            if currentTime >= activeClip.duration {
                if activeClip.loop {
                    currentTime = currentTime.truncatingRemainder(dividingBy: activeClip.duration)
                } else {
                    currentTime = activeClip.duration
                    pause()
                    onFrameUpdate?(currentTime)
                    return
                }
            }
        }

        animationEngine?.seek(to: Float(currentTime))
        onFrameUpdate?(currentTime)
    }

    deinit {
        displayLink?.invalidate()
    }

    // MARK: - Helpers

    private func formatTime(_ t: TimeInterval) -> String {
        let totalSeconds = Int(max(0, t))
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

/// Lightweight clip descriptor for the playback controller timeline.
/// Distinct from `AnimationClip` (the engine's generic keyframe container)
/// to avoid module-level symbol ambiguity.
struct PlaybackClip: Identifiable {
    let id: UUID
    var name: String
    var duration: TimeInterval
    var loop: Bool
    var isActive: Bool

    init(name: String, duration: TimeInterval, loop: Bool = false) {
        self.id = UUID()
        self.name = name
        self.duration = duration
        self.loop = loop
        self.isActive = false
    }
}

// MARK: - Comparable extensions

extension Float {
    func clamped(to range: ClosedRange<Float>) -> Float {
        max(range.lowerBound, min(range.upperBound, self))
    }
}

extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        max(range.lowerBound, min(range.upperBound, self))
    }
}
