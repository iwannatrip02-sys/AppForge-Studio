import XCTest
import simd
@testable import AppForgeStudio

final class AnimationEngineTests: XCTestCase {
    var engine: AnimationEngine!
    
    override func setUp() {
        super.setUp()
        engine = AnimationEngine()
    }
    
    func testInitialState() {
        XCTAssertFalse(engine.isPlaying)
        XCTAssertEqual(engine.currentTime, 0)
        XCTAssertEqual(engine.currentClipIndex, 0)
        XCTAssertEqual(engine.currentClipDuration, 2.0)
        XCTAssertEqual(engine.clips.count, 1)
    }
    
    func testPlayAndStop() {
        engine.play()
        XCTAssertTrue(engine.isPlaying)
        engine.stop()
        XCTAssertFalse(engine.isPlaying)
        XCTAssertEqual(engine.currentTime, 0)
    }
    
    func testTogglePlayPause() {
        engine.togglePlayPause()
        XCTAssertTrue(engine.isPlaying)
        engine.togglePlayPause()
        XCTAssertFalse(engine.isPlaying)
    }
    
    func testAddKeyframe() {
        let kf = Keyframe(time: 0.5, translation: SIMD3(1, 0, 0))
        engine.addKeyframe(nodeID: "Cube", keyframe: kf)
        let clip = engine.clips[0]
        let kfs = clip.keyframes["Cube"]
        XCTAssertNotNil(kfs)
        XCTAssertEqual(kfs?.count, 1)
        XCTAssertEqual(kfs?.first?.time, 0.5)
    }
    
    func testAddClip() {
        let clip = Clip(name: "TestClip", duration: 3.0, keyframes: [:])
        engine.addClip(clip)
        XCTAssertEqual(engine.clips.count, 2)
        engine.currentClipIndex = 1
        XCTAssertEqual(engine.currentClip?.name, "TestClip")
        XCTAssertEqual(engine.currentClipDuration, 3.0)
    }
    
    func testEvaluateAnimationSingleStep() {
        let kf1 = Keyframe(time: 0, translation: .zero)
        let kf2 = Keyframe(time: 1, translation: SIMD3(10, 0, 0))
        engine.addKeyframe(nodeID: "Cube", keyframe: kf1)
        engine.addKeyframe(nodeID: "Cube", keyframe: kf2)
        engine.play()
        let result = engine.evaluateAnimation(deltaTime: 0.5)
        // Debe estar en t=0.5, interpolacion lineal: x=5
        let transform = result["Cube"]!
        let pos = SIMD3(transform.columns.3.x, transform.columns.3.y, transform.columns.3.z)
        XCTAssertEqual(pos.x, 5.0, accuracy: 1e-4)
        XCTAssertTrue(engine.isPlaying)
    }
    
    func testEvaluateAnimationLoop() {
        let kf1 = Keyframe(time: 0, translation: .zero)
        let kf2 = Keyframe(time: 1, translation: SIMD3(10, 0, 0))
        engine.addKeyframe(nodeID: "Cube", keyframe: kf1)
        engine.addKeyframe(nodeID: "Cube", keyframe: kf2)
        engine.loop = true
        engine.play()
        let _ = engine.evaluateAnimation(deltaTime: 0.5) // t=0.5
        let _ = engine.evaluateAnimation(deltaTime: 0.6) // t=1.1, loop a 0
        let result = engine.evaluateAnimation(deltaTime: 0.0) // t=0
        let transform = result["Cube"]!
        let pos = SIMD3(transform.columns.3.x, transform.columns.3.y, transform.columns.3.z)
        XCTAssertEqual(pos.x, 0.0, accuracy: 1e-4)
        XCTAssertTrue(engine.isPlaying)
    }
    
    func testEvaluateAnimationNoLoop() {
        let kf1 = Keyframe(time: 0, translation: .zero)
        let kf2 = Keyframe(time: 1, translation: SIMD3(10, 0, 0))
        engine.addKeyframe(nodeID: "Cube", keyframe: kf1)
        engine.addKeyframe(nodeID: "Cube", keyframe: kf2)
        engine.loop = false
        engine.play()
        let _ = engine.evaluateAnimation(deltaTime: 2.0) // t=2, supera duracion
        // No loop: debe quedar en t=1, isPlaying=false
        XCTAssertFalse(engine.isPlaying)
        let result = engine.evaluateAnimation(deltaTime: 0.0) // engine detenido, no avanza
        let transform = result["Cube"]!
        let pos = SIMD3(transform.columns.3.x, transform.columns.3.y, transform.columns.3.z)
        XCTAssertEqual(pos.x, 10.0, accuracy: 1e-4)
    }
    
    func testMultipleNodes() {
        let kf1 = Keyframe(time: 0, translation: SIMD3(0, 0, 0))
        let kf2 = Keyframe(time: 1, translation: SIMD3(5, 0, 0))
        engine.addKeyframe(nodeID: "CubeA", keyframe: kf1)
        engine.addKeyframe(nodeID: "CubeA", keyframe: kf2)
        engine.addKeyframe(nodeID: "CubeB", keyframe: kf1)
        engine.addKeyframe(nodeID: "CubeB", keyframe: Keyframe(time: 1, translation: SIMD3(0, 10, 0)))
        engine.play()
        let result = engine.evaluateAnimation(deltaTime: 0.5)
        XCTAssertEqual(result.keys.count, 2)
        let posA = SIMD3(result["CubeA"]!.columns.3.x, result["CubeA"]!.columns.3.y, result["CubeA"]!.columns.3.z)
        let posB = SIMD3(result["CubeB"]!.columns.3.x, result["CubeB"]!.columns.3.y, result["CubeB"]!.columns.3.z)
        XCTAssertEqual(posA.x, 2.5, accuracy: 1e-4)
        XCTAssertEqual(posB.y, 5.0, accuracy: 1e-4)
    }
    
    func testKeyframeLerpTranslation() {
        let a = Keyframe(time: 0, translation: .zero)
        let b = Keyframe(time: 1, translation: SIMD3(10, 20, 30))
        let result = Keyframe.lerp(from: a, to: b, t: 0.5)
        XCTAssertEqual(result.translation.x, 5.0, accuracy: 1e-4)
        XCTAssertEqual(result.translation.y, 10.0, accuracy: 1e-4)
        XCTAssertEqual(result.translation.z, 15.0, accuracy: 1e-4)
    }
    
    func testKeyframeTransform() {
        let kf = Keyframe(time: 0, translation: SIMD3(1, 2, 3))
        let t = kf.transform
        let pos = SIMD3(t.columns.3.x, t.columns.3.y, t.columns.3.z)
        XCTAssertEqual(pos.x, 1.0, accuracy: 1e-4)
        XCTAssertEqual(pos.y, 2.0, accuracy: 1e-4)
        XCTAssertEqual(pos.z, 3.0, accuracy: 1e-4)
    }
}
