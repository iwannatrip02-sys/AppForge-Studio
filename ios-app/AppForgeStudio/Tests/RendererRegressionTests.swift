import XCTest
import MetalKit
import simd
@testable import AppForgeStudio

/// Regression tests for SatinRenderer scene rebuild behavior (BUG2, BUG9).
///
/// Verifies that `rebuildSceneFrom()` is called only when scene structure changes,
/// not on every transform update or animation frame.
@MainActor
final class RendererRegressionTests: XCTestCase {

    var device: MTLDevice!
    var renderer: SatinRenderer!

    override func setUp() {
        super.setUp()
        // Skip if Metal is unavailable (should not happen on simulator).
        guard let dev = MTLCreateSystemDefaultDevice() else {
            XCTFail("Metal device required for renderer regression tests")
            return
        }
        device = dev
        let mtkView = MTKView(frame: CGRect(x: 0, y: 0, width: 1, height: 1), device: device)
        renderer = SatinRenderer(mtkView: mtkView)
    }

    override func tearDown() {
        renderer = nil
        device = nil
        super.tearDown()
    }

    // MARK: - rebuildCount (BUG2/BUG9 regression)

    /// Initial state: rebuildCount must be 0 before any scene updates.
    func testRebuildCountStartsAtZero() {
        XCTAssertEqual(renderer.rebuildCount, 0,
            "rebuildCount inicial debe ser 0")
    }

    /// When updateScene receives a scene with different model count,
    /// structureChanged=true → rebuildSceneFrom() is called → rebuildCount += 1.
    func testRebuildCountIncrementsOnStructureChange() {
        let model = makeTestModel(name: "A", device: device)
        var scene = Scene3D()
        scene.addModel(model)

        renderer.updateScene(scene)
        XCTAssertEqual(renderer.rebuildCount, 1,
            "Primer updateScene con estructura diferente → rebuildCount = 1")
    }

    /// Calling updateScene again with the SAME model count must NOT trigger a rebuild.
    /// This is the regression test for BUG2 (doble rebuild por frame durante animacion)
    /// and BUG9 (rebuildSceneFrom cada frame).
    func testRebuildCountDoesNotIncrementWithoutStructureChange() {
        let modelA = makeTestModel(name: "A", device: device)
        var scene = Scene3D()
        scene.addModel(modelA)

        // First call: structure changes (0→1 models) → rebuild
        renderer.updateScene(scene)
        XCTAssertEqual(renderer.rebuildCount, 1)

        // Second call: same scene, same model count (1==1) → NO rebuild
        renderer.updateScene(scene)
        XCTAssertEqual(renderer.rebuildCount, 1,
            "Mismo numero de modelos → structureChanged=false → sin rebuild")

        // Third call: same again → still no rebuild
        renderer.updateScene(scene)
        XCTAssertEqual(renderer.rebuildCount, 1,
            "Tercer updateScene sin cambio estructural → rebuildCount sigue en 1")
    }

    /// When model count changes again, rebuildCount increments.
    func testRebuildCountIncrementsOnModelCountChange() {
        let modelA = makeTestModel(name: "A", device: device)
        var scene1 = Scene3D()
        scene1.addModel(modelA)

        renderer.updateScene(scene1)
        XCTAssertEqual(renderer.rebuildCount, 1, "1 modelo → rebuildCount = 1")

        // Add a second model → structure changes (1→2)
        let modelB = makeTestModel(name: "B", device: device)
        var scene2 = Scene3D()
        scene2.addModel(modelA)
        scene2.addModel(modelB)

        renderer.updateScene(scene2)
        XCTAssertEqual(renderer.rebuildCount, 2, "2 modelos (cambio) → rebuildCount = 2")

        // Remove one model → structure changes (2→1)
        var scene3 = Scene3D()
        scene3.addModel(modelB)

        renderer.updateScene(scene3)
        XCTAssertEqual(renderer.rebuildCount, 3, "1 modelo (cambio) → rebuildCount = 3")
    }

    /// Updating to an EMPTY scene (0 models) also counts as a structure change.
    func testRebuildCountIncrementsOnEmptyScene() {
        // Setup: start with 1 model
        let model = makeTestModel(name: "X", device: device)
        var scene1 = Scene3D()
        scene1.addModel(model)
        renderer.updateScene(scene1)
        XCTAssertEqual(renderer.rebuildCount, 1)

        // Transition to empty scene (1→0 models)
        let emptyScene = Scene3D()
        renderer.updateScene(emptyScene)
        XCTAssertEqual(renderer.rebuildCount, 2,
            "Escena vacia (0 modelos) tambien es cambio estructural")
    }

    // MARK: - Helpers

    /// Creates a Model with minimal valid vertex/index buffers so rebuildSceneFrom
    /// can process it without crashing. Uses the Model's native UInt16 index type.
    /// 13 floats per vertex (matches vertexCount = vertices.count / 13 in Model.init).
    private func makeTestModel(name: String, device: MTLDevice) -> Model {
        let vertices: [Float] = [
            0, 0, 0,  0, 1, 0,  0, 0,  1, 0, 0, 0, 0  // 1 vertex, 13 floats
        ]
        let indices: [UInt16] = [0]
        return Model(name: name, vertices: vertices, indices: indices, device: device)
    }
}
