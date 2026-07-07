import XCTest
import simd
import OCCTSwift
@testable import AppForgeStudio

/// Undo/redo B-rep: las operaciones de ingeniería deben ser reversibles con
/// restauración EXACTA de geometría (volumen) y malla de display.
@MainActor
final class BRepHistoryTests: XCTestCase {

    var history: BRepHistory!

    override func setUp() {
        super.setUp()
        history = BRepHistory.shared
        history.clear()
    }

    override func tearDown() {
        history.clear()
        super.tearDown()
    }

    private func makeBoxModel() throws -> Model {
        let shape = try XCTUnwrap(OCCTSwift.Shape.box(width: 2, height: 2, depth: 2))
        let mesh = try XCTUnwrap(OCCTBridge.toMesh(shape, quality: .medium))
        let model = Model(name: "HistBox")
        model.cadShape = shape
        model.meshes = [mesh]
        return model
    }

    private func volume(_ model: Model) throws -> Double {
        try XCTUnwrap(try XCTUnwrap(model.cadShape).volume)
    }

    func testUndoRestoresExactGeometryAndMesh() throws {
        let model = try makeBoxModel()
        let originalVolume = try volume(model)
        let originalVertexCount = model.meshes.first?.vertices.count ?? 0

        history.recordChange(of: model)
        XCTAssertTrue(BRepModeling.fillet(model, radius: 0.2))
        XCTAssertLessThan(try volume(model), originalVolume, "el fillet mutó el modelo")

        XCTAssertTrue(history.undo())
        XCTAssertEqual(try volume(model), originalVolume, accuracy: 1e-9,
                       "undo restaura el volumen EXACTO")
        XCTAssertEqual(model.meshes.first?.vertices.count, originalVertexCount,
                       "undo restaura la malla de display original")
    }

    func testRedoReappliesTheFeature() throws {
        let model = try makeBoxModel()
        let originalVolume = try volume(model)

        history.recordChange(of: model)
        XCTAssertTrue(BRepModeling.fillet(model, radius: 0.2))
        let filletedVolume = try volume(model)

        XCTAssertTrue(history.undo())
        XCTAssertTrue(history.redo())
        XCTAssertEqual(try volume(model), filletedVolume, accuracy: 1e-9,
                       "redo devuelve el estado con fillet")
        XCTAssertNotEqual(try volume(model), originalVolume)
    }

    func testNewChangeClearsRedoBranch() throws {
        let model = try makeBoxModel()
        history.recordChange(of: model)
        XCTAssertTrue(BRepModeling.fillet(model, radius: 0.1))
        XCTAssertTrue(history.undo())
        XCTAssertTrue(history.canRedo)

        history.recordChange(of: model)  // nueva rama de edición
        XCTAssertFalse(history.canRedo, "un cambio nuevo invalida el redo (historial lineal)")
    }

    func testDiscardLastDropsUnusedSnapshot() throws {
        let model = try makeBoxModel()
        history.recordChange(of: model)
        XCTAssertTrue(history.canUndo)
        history.discardLast()
        XCTAssertFalse(history.canUndo, "snapshot de operación fallida se descarta")
    }

    func testFullPushPullFlowIsUndoable() throws {
        let model = try makeBoxModel()
        let controller = PushPullController()
        controller.selectFace(from: SurfaceHit(modelIndex: 0, position: SIMD3<Float>(0, 0, 1),
                                               normal: SIMD3<Float>(0, 0, 1), distance: 9),
                              in: [model])
        controller.distance = 1.0
        XCTAssertTrue(controller.apply())
        XCTAssertEqual(try volume(model), 12.0, accuracy: 0.05)

        XCTAssertTrue(history.undo(), "el push/pull queda registrado en el historial")
        XCTAssertEqual(try volume(model), 8.0, accuracy: 0.01, "undo revierte el boss")
    }
}
