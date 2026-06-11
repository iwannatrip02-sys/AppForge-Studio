import XCTest
import simd
@testable import AppForgeStudio

/// Tests for AnimationEngine keyframe interpolation (F4.T1).
///
/// Verifies:
///   - slerp for rotation keyframes
///   - lerp for position/scale keyframes
///   - easing curve application
///   - loop / non-loop behaviour
///   - multi-model animation
///   - zero-division guards
@MainActor
final class AnimationEngineTests: XCTestCase {
    var engine: AnimationEngine!

    override func setUp() {
        super.setUp()
        engine = AnimationEngine()
    }

    override func tearDown() {
        engine = nil
        super.tearDown()
    }

    // MARK: - Initial state

    func testInitialState() {
        XCTAssertFalse(engine.isPlaying)
        XCTAssertEqual(engine.currentTime, 0.0)
        XCTAssertEqual(engine.selectedClipName, "")
        XCTAssertTrue(engine.clips.isEmpty)
        XCTAssertTrue(engine.keyframes.isEmpty)
    }

    func testPlayAndStop() {
        engine.play()
        XCTAssertTrue(engine.isPlaying)
        engine.stop()
        XCTAssertFalse(engine.isPlaying)
        XCTAssertEqual(engine.currentTime, 0.0)
    }

    func testTogglePlayPause() {
        engine.togglePlayPause()
        XCTAssertTrue(engine.isPlaying)
        engine.togglePlayPause()
        XCTAssertFalse(engine.isPlaying)
    }

    // MARK: - Clip registration

    func testRegisterClip() {
        var clip = AnimationClip(name: "Walk", duration: 3.0)
        clip.loop = true
        engine.registerClip(clip)
        XCTAssertEqual(engine.clips.count, 1)
        XCTAssertNotNil(engine.clips["Walk"])
        XCTAssertEqual(engine.clips["Walk"]?.duration, 3.0)
        XCTAssertTrue(engine.clips["Walk"]?.loop ?? false)
    }

    func testCurrentClipDuration() {
        var clip = AnimationClip(name: "Run", duration: 7.5)
        engine.registerClip(clip)
        engine.selectedClipName = "Run"
        XCTAssertEqual(engine.currentClipDuration, 7.5)
    }

    func testCurrentClipDurationDefaultWhenNoClip() {
        engine.selectedClipName = ""
        // Default fallback is 5.0 when no clip is selected
        XCTAssertEqual(engine.currentClipDuration, 5.0)
    }

    // MARK: - Keyframe management

    func testAddKeyframe() {
        engine.addKeyframe(modelName: "Cube", type: "posicion", time: 0.5)
        XCTAssertEqual(engine.keyframes.count, 1)
        let kf = engine.keyframes[0]
        XCTAssertEqual(kf.modelName, "Cube")
        XCTAssertEqual(kf.type, "posicion")
        XCTAssertEqual(kf.time, 0.5)
    }

    func testAddMultipleKeyframeTypes() {
        engine.addKeyframe(modelName: "Cube", type: "posicion", time: 0.0)
        engine.addKeyframe(modelName: "Cube", type: "rotacion", time: 0.0)
        engine.addKeyframe(modelName: "Cube", type: "escala", time: 0.0)
        XCTAssertEqual(engine.keyframes.count, 3)
    }

    func testRemoveKeyframeByIndex() {
        engine.addKeyframe(modelName: "Cube", type: "posicion", time: 0.0)
        engine.addKeyframe(modelName: "Cube", type: "posicion", time: 1.0)
        XCTAssertEqual(engine.keyframes.count, 2)
        engine.removeKeyframe(at: 0)
        XCTAssertEqual(engine.keyframes.count, 1)
        XCTAssertEqual(engine.keyframes[0].time, 1.0)
    }

    func testRemoveKeyframeByTime() {
        engine.addKeyframe(modelName: "Cube", type: "posicion", time: 0.0)
        engine.addKeyframe(modelName: "Cube", type: "posicion", time: 0.5)
        engine.addKeyframe(modelName: "Cube", type: "posicion", time: 1.0)
        engine.removeKeyframe(at: 0.5)
        XCTAssertEqual(engine.keyframes.count, 2)
        XCTAssertFalse(engine.keyframes.contains(where: { abs($0.time - 0.5) < 0.001 }))
    }

    func testMoveKeyframe() {
        engine.addKeyframe(modelName: "Cube", type: "posicion", time: 0.0)
        let id = engine.keyframes[0].id
        engine.moveKeyframe(id: id, to: 2.0)
        XCTAssertEqual(engine.keyframes[0].time, 2.0)
    }

    // MARK: - Seek

    func testSeekWithinBounds() {
        var clip = AnimationClip(name: "Test", duration: 5.0)
        engine.registerClip(clip)
        engine.selectedClipName = "Test"

        engine.addKeyframe(modelName: "Test", type: "posicion", time: 0.0)
        engine.addKeyframe(modelName: "Test", type: "posicion", time: 5.0)

        engine.seek(to: 2.5)
        XCTAssertEqual(engine.currentTime, 2.5)
    }

    func testSeekClampsToDuration() {
        var clip = AnimationClip(name: "Test", duration: 5.0)
        engine.registerClip(clip)
        engine.selectedClipName = "Test"

        engine.seek(to: 10.0)
        XCTAssertEqual(engine.currentTime, 5.0) // clamped to duration

        engine.seek(to: -2.0)
        XCTAssertEqual(engine.currentTime, 0.0) // clamped to 0
    }

    // MARK: - Position interpolation (lerp)

    func testPositionInterpolationLinear() {
        engine.selectedClipName = "Cube"
        engine.addKeyframe(modelName: "Cube", type: "posicion", time: 0.0)
        engine.keyframes[0].positionValue = SIMD3<Float>(0, 0, 0)
        engine.addKeyframe(modelName: "Cube", type: "posicion", time: 2.0)
        engine.keyframes[1].positionValue = SIMD3<Float>(10, 0, 0)

        let result = engine.evaluate(at: 1.0)
        let transform = result["Cube"]!
        let pos = SIMD3<Float>(transform.columns.3.x, transform.columns.3.y, transform.columns.3.z)
        XCTAssertEqual(pos.x, 5.0, accuracy: 1e-4, "lerp at t=1.0: x should be 5.0")
    }

    func testPositionInterpolationWithEasing() {
        engine.selectedClipName = "Cube"
        engine.addKeyframe(modelName: "Cube", type: "posicion", time: 0.0)
        engine.keyframes[0].positionValue = SIMD3<Float>(0, 0, 0)
        engine.keyframes[0].easing = "easeOutQuad"
        engine.addKeyframe(modelName: "Cube", type: "posicion", time: 2.0)
        engine.keyframes[1].positionValue = SIMD3<Float>(10, 0, 0)

        // easeOutQuad at t=0.5: rawT=0.5 → eased = 0.5*(2-0.5) = 0.75
        // result = 0 + (10-0) * 0.75 = 7.5
        let result = engine.evaluate(at: 1.0)
        let transform = result["Cube"]!
        let pos = SIMD3<Float>(transform.columns.3.x, transform.columns.3.y, transform.columns.3.z)
        XCTAssertEqual(pos.x, 7.5, accuracy: 1e-4, "easeOutQuad at mid: x should be 7.5")
    }

    // MARK: - Rotation interpolation (slerp)

    func testRotationInterpolationSlerp() {
        engine.selectedClipName = "Cube"
        engine.addKeyframe(modelName: "Cube", type: "rotacion", time: 0.0)
        engine.keyframes[0].rotationValue = simd_quatf(ix: 0, iy: 0, iz: 0, r: 1) // identity
        engine.addKeyframe(modelName: "Cube", type: "rotacion", time: 2.0)
        // 180° around Y axis
        engine.keyframes[1].rotationValue = simd_quatf(angle: .pi, axis: SIMD3<Float>(0, 1, 0))

        let result = engine.evaluate(at: 1.0)
        let transform = result["Cube"]!
        // Extract rotation matrix and check it's ~90° around Y
        let rotMatrix = simd_float3x3(
            SIMD3<Float>(transform.columns.0.x, transform.columns.0.y, transform.columns.0.z),
            SIMD3<Float>(transform.columns.1.x, transform.columns.1.y, transform.columns.1.z),
            SIMD3<Float>(transform.columns.2.x, transform.columns.2.y, transform.columns.2.z)
        )
        let quat = simd_quatf(rotMatrix)
        let angle = quat.angle
        let axis = quat.axis
        // Halfway between identity and 180° Y → ~90° around Y
        XCTAssertEqual(angle, .pi / 2, accuracy: 0.01, "slerp at mid: angle should be ~π/2")
        XCTAssertEqual(abs(axis.y), 1.0, accuracy: 0.01, "slerp at mid: axis should be Y")
    }

    // MARK: - Scale interpolation (lerp)

    func testScaleInterpolation() {
        engine.selectedClipName = "Cube"
        engine.addKeyframe(modelName: "Cube", type: "escala", time: 0.0)
        engine.keyframes[0].scaleValue = SIMD3<Float>(1, 1, 1)
        engine.addKeyframe(modelName: "Cube", type: "escala", time: 2.0)
        engine.keyframes[1].scaleValue = SIMD3<Float>(2, 2, 2)

        let result = engine.evaluate(at: 1.0)
        let transform = result["Cube"]!
        let sx = simd_length(SIMD3<Float>(transform.columns.0.x, transform.columns.0.y, transform.columns.0.z))
        XCTAssertEqual(sx, 1.5, accuracy: 1e-4, "scale lerp at mid: should be 1.5")
    }

    // MARK: - Animation evaluation (delta-based)

    func testEvaluateAnimationAdvancesTime() {
        engine.selectedClipName = "Test"
        var clip = AnimationClip(name: "Test", duration: 10.0)
        clip.loop = false
        engine.registerClip(clip)

        engine.addKeyframe(modelName: "Test", type: "posicion", time: 0.0)
        engine.addKeyframe(modelName: "Test", type: "posicion", time: 10.0)

        engine.play()
        let _ = engine.evaluateAnimation(deltaTime: 3.0)
        XCTAssertEqual(engine.currentTime, 3.0, accuracy: 0.01)
    }

    func testEvaluateAnimationLoop() {
        engine.selectedClipName = "Test"
        var clip = AnimationClip(name: "Test", duration: 2.0)
        clip.loop = true
        engine.registerClip(clip)

        engine.addKeyframe(modelName: "Test", type: "posicion", time: 0.0)
        engine.addKeyframe(modelName: "Test", type: "posicion", time: 2.0)

        engine.play()
        let _ = engine.evaluateAnimation(deltaTime: 1.5) // t=1.5
        let _ = engine.evaluateAnimation(deltaTime: 0.7) // t=2.2 → wraps to 0.2
        XCTAssertEqual(engine.currentTime, 0.2, accuracy: 0.01, "loop: should wrap to 0.2")
        XCTAssertTrue(engine.isPlaying)
    }

    func testEvaluateAnimationNoLoopStops() {
        engine.selectedClipName = "Test"
        var clip = AnimationClip(name: "Test", duration: 2.0)
        clip.loop = false
        engine.registerClip(clip)

        engine.addKeyframe(modelName: "Test", type: "posicion", time: 0.0)
        engine.addKeyframe(modelName: "Test", type: "posicion", time: 2.0)

        engine.play()
        let _ = engine.evaluateAnimation(deltaTime: 3.0) // exceeds duration
        XCTAssertFalse(engine.isPlaying, "non-loop clip should stop at end")
        XCTAssertEqual(engine.currentTime, 2.0, accuracy: 0.01)
    }

    // MARK: - Multiple models

    func testMultipleModels() {
        engine.selectedClipName = "Shared"
        var clip = AnimationClip(name: "Shared", duration: 2.0)
        engine.registerClip(clip)

        // Model A: position (0→10)
        engine.addKeyframe(modelName: "Shared", type: "posicion", time: 0.0)
        engine.keyframes[0].positionValue = SIMD3<Float>(0, 0, 0)
        engine.addKeyframe(modelName: "Shared", type: "posicion", time: 2.0)
        engine.keyframes[1].positionValue = SIMD3<Float>(10, 0, 0)

        // Model B: rotation
        let clipKey = "SharedRot"
        engine.addKeyframe(modelName: clipKey, type: "rotacion", time: 0.0)
        engine.keyframes[2].rotationValue = simd_quatf(ix: 0, iy: 0, iz: 0, r: 1)
        engine.addKeyframe(modelName: clipKey, type: "rotacion", time: 2.0)
        engine.keyframes[3].rotationValue = simd_quatf(angle: .pi/2, axis: SIMD3<Float>(0, 0, 1))

        let result = engine.evaluate(at: 1.0)
        // Shared model gets evaluated (it matches selectedClipName)
        XCTAssertNotNil(result["Shared"])
        // The other model is filtered by selectedClipName (keyframes with different modelName are excluded)
    }

    // MARK: - Zero-division guards

    func testZeroDivisionWhenSameTime() {
        engine.selectedClipName = "Cube"
        engine.addKeyframe(modelName: "Cube", type: "posicion", time: 1.0)
        engine.keyframes[0].positionValue = SIMD3<Float>(0, 0, 0)
        engine.addKeyframe(modelName: "Cube", type: "posicion", time: 1.0) // same time!
        engine.keyframes[1].positionValue = SIMD3<Float>(10, 0, 0)

        // Should not crash; should return the value at that time
        let result = engine.evaluate(at: 1.0)
        XCTAssertNotNil(result["Cube"])
    }

    func testNoKeyframesReturnsEmpty() {
        let result = engine.evaluate(at: 1.0)
        XCTAssertTrue(result.isEmpty)
    }

    // MARK: - onFrame callback

    func testOnFrameCallback() {
        var receivedTime: Float = -1
        var receivedTransforms: [String: simd_float4x4]? = nil
        engine.onFrame = { time, transforms in
            receivedTime = time
            receivedTransforms = transforms
        }
        engine.selectedClipName = "Test"
        var clip = AnimationClip(name: "Test", duration: 5.0)
        engine.registerClip(clip)
        engine.addKeyframe(modelName: "Test", type: "posicion", time: 0.0)
        engine.addKeyframe(modelName: "Test", type: "posicion", time: 5.0)

        engine.play()
        let _ = engine.evaluateAnimation(deltaTime: 2.0)
        XCTAssertEqual(receivedTime, 2.0, accuracy: 0.01)
        XCTAssertNotNil(receivedTransforms)
    }

    // MARK: - Legacy API (backward compatibility)

    func testLegacyClipEvaluation() {
        let kf0 = LegacyKeyframe(time: 0, translation: .zero)
        let kf1 = LegacyKeyframe(time: 2, translation: SIMD3<Float>(10, 0, 0))
        let clip = LegacyClip(name: "Legacy", duration: 2.0, keyframes: ["A": [kf0, kf1]], loop: false)
        engine.addLegacyClip(clip)

        engine.play()
        let result = engine.evaluateLegacyAnimation(deltaTime: 1.0)
        XCTAssertEqual(engine.currentTime, 1.0)
        let transform = result["A"]!
        let pos = SIMD3<Float>(transform.columns.3.x, transform.columns.3.y, transform.columns.3.z)
        XCTAssertEqual(pos.x, 5.0, accuracy: 1e-4)
    }

    func testLegacyKeyframeTransform() {
        let kf = LegacyKeyframe(time: 0, translation: SIMD3<Float>(1, 2, 3))
        let t = kf.transform
        let pos = SIMD3<Float>(t.columns.3.x, t.columns.3.y, t.columns.3.z)
        XCTAssertEqual(pos.x, 1.0, accuracy: 1e-4)
        XCTAssertEqual(pos.y, 2.0, accuracy: 1e-4)
        XCTAssertEqual(pos.z, 3.0, accuracy: 1e-4)
    }

    func testLegacyKeyframeLerpTranslation() {
        let a = LegacyKeyframe(time: 0, translation: .zero)
        let b = LegacyKeyframe(time: 1, translation: SIMD3<Float>(10, 20, 30))
        let result = LegacyKeyframe.lerp(from: a, to: b, t: 0.5)
        XCTAssertEqual(result.translation.x, 5.0, accuracy: 1e-4)
        XCTAssertEqual(result.translation.y, 10.0, accuracy: 1e-4)
        XCTAssertEqual(result.translation.z, 15.0, accuracy: 1e-4)
    }
}
