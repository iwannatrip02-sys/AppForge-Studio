import XCTest
@testable import AppForgeStudio

/// Tests for AnimationPlaybackController (F4.T1).
///
/// Verifies transport controls, seek, progress, speed, time formatting,
/// and integration with AnimationEngine.
@MainActor
final class AnimationPlaybackTests: XCTestCase {

    var engine: AnimationEngine!
    var controller: AnimationPlaybackController!

    override func setUp() {
        super.setUp()
        engine = AnimationEngine()

        var clip = AnimationClip(name: "TestClip", duration: 10.0)
        clip.loop = false
        engine.registerClip(clip)
        engine.selectedClipName = "TestClip"

        controller = AnimationPlaybackController(animationEngine: engine)
    }

    override func tearDown() {
        controller = nil
        engine = nil
        super.tearDown()
    }

    // MARK: - Transport lifecycle

    func testPlaybackLifecycle() {
        XCTAssertFalse(controller.isPlaying)
        XCTAssertEqual(controller.currentTime, 0)

        controller.play()
        XCTAssertTrue(controller.isPlaying)

        controller.pause()
        XCTAssertFalse(controller.isPlaying)

        controller.togglePlayback()
        XCTAssertTrue(controller.isPlaying)

        controller.stop()
        XCTAssertFalse(controller.isPlaying)
        XCTAssertEqual(controller.currentTime, 0)
    }

    // MARK: - Seek

    func testSeekWithinBounds() {
        controller.seek(to: 5.0)
        XCTAssertEqual(controller.currentTime, 5.0)
        XCTAssertEqual(engine.currentTime, 5.0)

        controller.seek(to: 0.0)
        XCTAssertEqual(controller.currentTime, 0.0)
    }

    func testSeekClampsToDuration() {
        controller.seek(to: 20.0)
        XCTAssertEqual(controller.currentTime, 10.0) // clamped to duration

        controller.seek(to: -5.0)
        XCTAssertEqual(controller.currentTime, 0.0) // clamped to 0
    }

    // MARK: - Progress

    func testProgressCalculation() {
        controller.seek(to: 0.0)
        XCTAssertEqual(controller.progress, 0.0)

        controller.seek(to: 5.0)
        XCTAssertEqual(controller.progress, 0.5)

        controller.seek(to: 10.0)
        XCTAssertEqual(controller.progress, 1.0)
    }

    // MARK: - Speed

    func testSpeedDefaults() {
        XCTAssertEqual(controller.playbackSpeed, 1.0)
        XCTAssertEqual(controller.speedMultiplier, 1.0)
    }

    func testSetSpeed() {
        controller.setSpeed(2.0)
        XCTAssertEqual(controller.playbackSpeed, 2.0)

        controller.setSpeed(0.0)
        XCTAssertEqual(controller.playbackSpeed, 0.1) // minimum clamp

        controller.setSpeed(15.0)
        XCTAssertEqual(controller.playbackSpeed, 10.0) // maximum clamp
    }

    func testPlaybackSpeedProperty() {
        controller.playbackSpeed = 3.0
        XCTAssertEqual(controller.speedMultiplier, 3.0)

        controller.playbackSpeed = -1.0 // below min
        XCTAssertEqual(controller.speedMultiplier, 0.1)

        controller.playbackSpeed = 100.0 // above max
        XCTAssertEqual(controller.speedMultiplier, 10.0)
    }

    // MARK: - Time formatting

    func testTimeAndDurationStrings() {
        controller.seek(to: 0.0)
        XCTAssertEqual(controller.timeString, "0:00")
        XCTAssertEqual(controller.durationString, "0:10")

        controller.seek(to: 5.0)
        XCTAssertEqual(controller.timeString, "0:05")

        controller.seek(to: 10.0)
        XCTAssertEqual(controller.timeString, "0:10")
    }

    func testTimeFormattingMinutes() {
        // Create a longer clip
        var clip = AnimationClip(name: "Long", duration: 125.0) // 2min 5sec
        engine.registerClip(clip)
        engine.selectedClipName = "Long"
        controller.seek(to: 65.0) // 1min 5sec
        XCTAssertEqual(controller.timeString, "1:05")
        XCTAssertEqual(controller.durationString, "2:05")
    }

    // MARK: - Looping

    func testIsLoopingDetection() {
        XCTAssertFalse(controller.isLooping)

        var clip = engine.clips["TestClip"]!
        clip.loop = true
        engine.registerClip(clip)

        XCTAssertTrue(engine.clips["TestClip"]?.loop ?? false)
    }

    // MARK: - Animation name

    func testAnimationName() {
        XCTAssertEqual(controller.animationName, "TestClip")

        engine.selectedClipName = ""
        // When no clip name, shows placeholder
        XCTAssertEqual(controller.animationName, "Sin animacion")
    }

    // MARK: - External tick (SatinRenderer integration)

    func testExternalTickAdvancesTime() {
        controller.play()
        controller.tick(deltaTime: 2.0)
        XCTAssertEqual(controller.currentTime, 2.0, accuracy: 0.01)
        XCTAssertTrue(controller.isPlaying)
    }

    func testExternalTickWithSpeed() {
        controller.setSpeed(2.0)
        controller.play()
        controller.tick(deltaTime: 1.0)
        // deltaTime 1.0 × speed 2.0 = 2.0 seconds advanced
        XCTAssertEqual(controller.currentTime, 2.0, accuracy: 0.01)
    }

    func testExternalTickLoop() {
        var clip = engine.clips["TestClip"]!
        clip.loop = true
        engine.registerClip(clip)

        // Add a clip to the controller
        let pbClip = PlaybackClip(name: "TestClip", duration: 5.0, loop: true)
        var active = pbClip
        active.isActive = true
        controller.addClip(active)

        controller.play()
        controller.tick(deltaTime: 3.0) // t=3
        controller.tick(deltaTime: 3.0) // t=6 → wraps to 1.0
        XCTAssertEqual(controller.currentTime, 1.0, accuracy: 0.01)
    }

    func testExternalTickNonLoopStops() {
        var clip = engine.clips["TestClip"]!
        clip.loop = false
        engine.registerClip(clip)

        let pbClip = PlaybackClip(name: "TestClip", duration: 5.0, loop: false)
        var active = pbClip
        active.isActive = true
        controller.addClip(active)

        controller.play()
        controller.tick(deltaTime: 6.0) // exceeds duration (5.0)
        XCTAssertEqual(controller.currentTime, 5.0, accuracy: 0.01)
        XCTAssertFalse(controller.isPlaying)
    }
}
