import XCTest
@testable import AppForgeStudio

@MainActor
final class AnimationPlaybackTests: XCTestCase {
    
    var engine: AnimationEngine!
    var controller: AnimationPlaybackController!
    
    override func setUp() {
        super.setUp()
        engine = AnimationEngine()
        
        let clip = AnimationClip(name: "TestClip", duration: 10.0)
        clip.loop = false
        engine.registerClip(clip)
        engine.selectedClipName = "TestClip"
        
        controller = AnimationPlaybackController(animationEngine: engine)
    }
    
    func testPlaybackLifecycle() {
        // Given: controller inicializado
        XCTAssertFalse(controller.isPlaying)
        XCTAssertEqual(controller.currentTime, 0)
        
        // When: play
        controller.play()
        XCTAssertTrue(controller.isPlaying)
        
        // When: pause
        controller.pause()
        XCTAssertFalse(controller.isPlaying)
        
        // When: resume (toggle)
        controller.togglePlayback()
        XCTAssertTrue(controller.isPlaying)
        
        // When: stop
        controller.stop()
        XCTAssertFalse(controller.isPlaying)
        XCTAssertEqual(controller.currentTime, 0)
    }
    
    func testSeekWithinBounds() {
        // Given: duracion 10.0
        
        // When: seek a mitad
        controller.seek(to: 5.0)
        XCTAssertEqual(controller.currentTime, 5.0)
        XCTAssertEqual(engine.currentTime, 5.0)
        
        // When: seek a 0
        controller.seek(to: 0.0)
        XCTAssertEqual(controller.currentTime, 0.0)
        
        // When: seek mas alla de duracion
        controller.seek(to: 20.0)
        XCTAssertEqual(controller.currentTime, 10.0) // limitado a duration
        
        // When: seek a negativo
        controller.seek(to: -5.0)
        XCTAssertEqual(controller.currentTime, 0.0) // limitado a 0
    }
    
    func testProgressCalculation() {
        controller.seek(to: 0.0)
        XCTAssertEqual(controller.progress, 0.0)
        
        controller.seek(to: 5.0)
        XCTAssertEqual(controller.progress, 0.5)
        
        controller.seek(to: 10.0)
        XCTAssertEqual(controller.progress, 1.0)
    }
    
    func testSpeedChanges() {
        // Given: speed por defecto 1.0
        XCTAssertEqual(controller.playbackSpeed, 1.0)
        
        // When: setSpeed 2.0
        controller.setSpeed(2.0)
        XCTAssertEqual(controller.playbackSpeed, 2.0)
        
        // When: setSpeed 0.0 (debajo del minimo)
        controller.setSpeed(0.0)
        XCTAssertEqual(controller.playbackSpeed, 0.1) // minimo clamp
        
        // When: setSpeed 15.0 (encima del maximo)
        controller.setSpeed(15.0)
        XCTAssertEqual(controller.playbackSpeed, 10.0) // maximo clamp
    }
    
    func testTimeAndDurationStrings() {
        // Given: duracion 10.0
        controller.seek(to: 0.0)
        XCTAssertEqual(controller.timeString, "0:00")
        XCTAssertEqual(controller.durationString, "0:10")
        
        controller.seek(to: 5.0)
        XCTAssertEqual(controller.timeString, "0:05")
        
        controller.seek(to: 10.0)
        XCTAssertEqual(controller.timeString, "0:10")
    }
    
    func testIsLoopingDetection() {
        // Given: clip sin loop
        XCTAssertFalse(controller.isLooping)
        
        // When: cambiar a loop
        var clip = engine.clips["TestClip"]!
        clip.loop = true
        engine.registerClip(clip)
        
        // Then: detectado correctamente
        let looping = controller.isLooping
        XCTAssertTrue(looping)
    }
    
    func testMorphTarget() {
        var mesh = Mesh()
        mesh.baseVertices = [
            Vertex(position: SIMD3<Float>(0, 0, 0)),
            Vertex(position: SIMD3<Float>(1, 0, 0)),
            Vertex(position: SIMD3<Float>(0, 1, 0)),
            Vertex(position: SIMD3<Float>(0, 0, 1))
        ]
        mesh.vertices = mesh.baseVertices
        let deformed = [
            Vertex(position: SIMD3<Float>(1, 0, 0)),
            Vertex(position: SIMD3<Float>(2, 0, 0)),
            Vertex(position: SIMD3<Float>(1, 1, 0)),
            Vertex(position: SIMD3<Float>(1, 0, 1))
        ]
        let target = MorphEngine.createMorphTarget(from: mesh, name: "stretch", deformedVertices: deformed)
        XCTAssertEqual(target.name, "stretch")
        XCTAssertEqual(target.offsets.count, 4)
        XCTAssertEqual(target.offsets[0], SIMD3<Float>(1, 0, 0))
        mesh.morphTargets = [target]
        mesh.morphTargets[0].weight = 1.0
        mesh.applyMorphs()
        XCTAssertEqual(mesh.vertices[0].position, SIMD3<Float>(1, 0, 0))
        XCTAssertEqual(mesh.vertices[1].position, SIMD3<Float>(2, 0, 0))
    }

    func testMorphAnimation() {
        var clip = AnimationClip(name: "MorphTest", duration: 2.0)
        clip.morphFrames["smile"] = [
            Keyframe<Float>(time: 0, value: 0),
            Keyframe<Float>(time: 2, value: 1)
        ]

        var mesh = Mesh()
        mesh.baseVertices = [
            Vertex(position: SIMD3<Float>(0, 0, 0)),
            Vertex(position: SIMD3<Float>(1, 0, 0))
        ]
        mesh.vertices = mesh.baseVertices
        let deformed = [
            Vertex(position: SIMD3<Float>(0, 1, 0)),
            Vertex(position: SIMD3<Float>(1, 1, 0))
        ]
        let target = MorphEngine.createMorphTarget(from: mesh, name: "smile", deformedVertices: deformed)
        mesh.morphTargets = [target]

        MorphEngine.applyAllMorphs(to: &mesh, at: 1.0, clip: clip)
        XCTAssertEqual(mesh.morphTargets[0].weight, 0.5, accuracy: 1e-4)
        XCTAssertEqual(mesh.vertices[0].position.y, 0.5, accuracy: 1e-4)
    }

    func testMorphBlend() {
        var mesh = Mesh()
        mesh.baseVertices = [
            Vertex(position: SIMD3<Float>(0, 0, 0)),
            Vertex(position: SIMD3<Float>(1, 0, 0))
        ]
        mesh.vertices = mesh.baseVertices
        let d1 = [Vertex(position: SIMD3<Float>(0, 2, 0)), Vertex(position: SIMD3<Float>(1, 2, 0))]
        let t1 = MorphEngine.createMorphTarget(from: mesh, name: "up", deformedVertices: d1)
        mesh.morphTargets = [t1]
        MorphEngine.blendMorphs(on: &mesh, weights: ["up": 0.5])
        XCTAssertEqual(mesh.vertices[0].position.y, 1.0, accuracy: 1e-4)
    }

    func testPlaybackNameChange() {
        XCTAssertEqual(controller.animationName, "TestClip")
        
        engine.selectedClipName = ""
        // Nota: la actualizacion via Combine es async, damos oportunidad
        let expectation = XCTestExpectation(description: "Name update")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            XCTAssertEqual(self.controller.animationName, "Sin animacion")
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 0.5)
    }
}
