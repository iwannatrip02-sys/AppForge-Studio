import Foundation
import QuartzCore
import Combine

class AnimationPlaybackController: ObservableObject {
    @Published var currentTime: TimeInterval = 0
    @Published var isPlaying: Bool = false
    @Published var clips: [AnimationClip] = []
    @Published var speedMultiplier: Float = 1.0
    
    private var displayLink: CADisplayLink?
    private var lastTimestamp: TimeInterval = 0
    private var animationEngine: AnimationEngine?
    var onFrameUpdate: ((TimeInterval) -> Void)?
    
    init(animationEngine: AnimationEngine?) {
        self.animationEngine = animationEngine
    }
    
    func play() {
        guard !isPlaying else { return }
        isPlaying = true
        lastTimestamp = CACurrentMediaTime()
        displayLink = CADisplayLink(target: self, selector: #selector(tick))
        displayLink?.add(to: .main, forMode: .common)
    }
    
    func pause() {
        isPlaying = false
        displayLink?.invalidate()
        displayLink = nil
    }
    
    func stop() {
        pause()
        currentTime = 0
        animationEngine?.stop()
        onFrameUpdate?(currentTime)
    }
    
    func seek(to time: TimeInterval) {
        currentTime = max(0, time)
        animationEngine?.seek(to: Float(time))
        onFrameUpdate?(currentTime)
    }
    
    func addClip(_ clip: AnimationClip) {
        clips.append(clip)
    }
    
    func removeClip(_ clip: AnimationClip) {
        clips.removeAll { $0.id == clip.id }
    }
    
    @objc private func tick() {
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
}

struct AnimationClip: Identifiable {
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
