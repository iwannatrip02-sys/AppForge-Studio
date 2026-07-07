import XCTest
import simd
import OCCTSwift
@testable import AppForgeStudio

/// Tests del flujo interactivo completo de push/pull:
/// hit de superficie → selección de cara B-rep → aplicar boss/pocket → volumen exacto.
@MainActor
final class PushPullControllerTests: XCTestCase {

    private func makeBoxModel() throws -> Model {
        let shape = try XCTUnwrap(OCCTSwift.Shape.box(width: 2, height: 2, depth: 2))
        let mesh = try XCTUnwrap(OCCTBridge.toMesh(shape, quality: .medium))
        let model = Model(name: "PPBox")
        model.cadShape = shape
        model.meshes = [mesh]
        return model
    }

    /// Hit sintético en el centro de la cara superior de la caja centrada [-1,1]³.
    private func topFaceHit() -> SurfaceHit {
        SurfaceHit(modelIndex: 0, position: SIMD3<Float>(0, 0, 1),
                   normal: SIMD3<Float>(0, 0, 1), distance: 9)
    }

    func testSelectFaceFromSurfaceHit() throws {
        let model = try makeBoxModel()
        let controller = PushPullController()

        controller.selectFace(from: topFaceHit(), in: [model])
        XCTAssertTrue(controller.hasSelection, "el hit sobre la cara superior debe seleccionarla")
    }

    func testApplyBossThroughFullFlowAddsExactVolume() throws {
        let model = try makeBoxModel()
        let controller = PushPullController()
        controller.selectFace(from: topFaceHit(), in: [model])
        controller.distance = 1.0

        XCTAssertTrue(controller.apply())
        let volume = try XCTUnwrap(try XCTUnwrap(model.cadShape).volume)
        XCTAssertEqual(volume, 12.0, accuracy: 0.05,
                       "boss de 2×2×1 sobre la cara superior: 8+4=12")
        XCTAssertFalse(controller.hasSelection, "tras aplicar, la selección se limpia")
        XCTAssertFalse(model.meshes.first?.vertices.isEmpty ?? true,
                       "la malla de display se re-triangula")
    }

    func testApplyPocketRemovesExactVolume() throws {
        let model = try makeBoxModel()
        let controller = PushPullController()
        controller.selectFace(from: topFaceHit(), in: [model])
        controller.distance = -1.0

        XCTAssertTrue(controller.apply())
        let volume = try XCTUnwrap(try XCTUnwrap(model.cadShape).volume)
        XCTAssertEqual(volume, 4.0, accuracy: 0.05, "pocket de 2×2×1: 8-4=4")
    }

    func testModelWithoutBRepIsRejectedWithClearMessage() {
        let model = Model(name: "Esculpido")  // sin cadShape
        let controller = PushPullController()

        controller.selectFace(from: topFaceHit(), in: [model])
        XCTAssertFalse(controller.hasSelection)
        XCTAssertTrue(controller.statusMessage.contains("B-rep"),
                      "el mensaje debe explicar por qué no aplica")
    }

    func testZeroDistanceDoesNotApply() throws {
        let model = try makeBoxModel()
        let controller = PushPullController()
        controller.selectFace(from: topFaceHit(), in: [model])
        controller.distance = 0

        XCTAssertFalse(controller.apply())
        let volume = try XCTUnwrap(try XCTUnwrap(model.cadShape).volume)
        XCTAssertEqual(volume, 8.0, accuracy: 0.01, "sin distancia, el modelo queda intacto")
    }
}
