import XCTest
import simd
import OCCTSwift
@testable import AppForgeStudio

/// Tests del flujo contextual de arista (Ola 3, BLUEPRINT S2):
/// hit de superficie → arista B-rep más cercana → fillet selectivo → volumen exacto.
@MainActor
final class EdgeFilletControllerTests: XCTestCase {

    private func makeBoxModel() throws -> Model {
        let shape = try XCTUnwrap(OCCTSwift.Shape.box(width: 2, height: 2, depth: 2))
        let mesh = try XCTUnwrap(OCCTBridge.toMesh(shape, quality: .medium))
        let model = Model(name: "EFBox")
        model.cadShape = shape
        model.meshes = [mesh]
        return model
    }

    /// Hit sintético en el punto medio de la arista superior x=1,z=1 de la caja [-1,1]³.
    private func edgeHit() -> SurfaceHit {
        SurfaceHit(modelIndex: 0, position: SIMD3<Float>(1, 0, 1),
                   normal: SIMD3<Float>(1, 0, 0), distance: 9)
    }

    func testSelectEdgeFromSurfaceHit() throws {
        let model = try makeBoxModel()
        let controller = EdgeFilletController()

        XCTAssertTrue(controller.selectEdge(from: edgeHit(), in: [model]),
                      "el hit sobre la arista debe seleccionarla")
        XCTAssertTrue(controller.hasSelection)
        XCTAssertNotNil(controller.highlightMesh, "la selección genera el tubo de highlight")
        XCTAssertFalse(controller.highlightMesh?.vertices.isEmpty ?? true)
    }

    func testTapOnFaceCenterDoesNotSelectEdge() throws {
        let model = try makeBoxModel()
        let controller = EdgeFilletController()
        let faceHit = SurfaceHit(modelIndex: 0, position: SIMD3<Float>(0, 0, 1),
                                 normal: SIMD3<Float>(0, 0, 1), distance: 9)

        XCTAssertFalse(controller.selectEdge(from: faceHit, in: [model]),
                       "el centro de una cara está lejos de toda arista")
        XCTAssertFalse(controller.hasSelection)
    }

    func testApplyFilletRemovesExactVolume() throws {
        let model = try makeBoxModel()
        let controller = EdgeFilletController()
        controller.selectEdge(from: edgeHit(), in: [model])
        controller.radius = 0.2

        XCTAssertTrue(controller.applyFillet())
        // Fillet r sobre UNA arista de longitud L quita (1 − π/4)·r²·L:
        // (1 − 0.7854)·0.04·2 ≈ 0.01717 → volumen ≈ 7.9828
        let volume = try XCTUnwrap(try XCTUnwrap(model.cadShape).volume)
        XCTAssertEqual(volume, 8.0 - (1.0 - Double.pi / 4.0) * 0.04 * 2.0, accuracy: 0.01,
                       "el fillet selectivo quita exactamente (1−π/4)·r²·L de UNA arista")
        XCTAssertFalse(controller.hasSelection, "tras aplicar, la selección se limpia")
        XCTAssertFalse(model.meshes.first?.vertices.isEmpty ?? true,
                       "la malla de display se re-triangula")
    }

    func testImpossibleRadiusFailsWithoutMutating() throws {
        let model = try makeBoxModel()
        let controller = EdgeFilletController()
        controller.selectEdge(from: edgeHit(), in: [model])
        controller.radius = 5.0  // no cabe en una caja de 2

        XCTAssertFalse(controller.applyFillet(), "un radio imposible debe fallar")
        let volume = try XCTUnwrap(try XCTUnwrap(model.cadShape).volume)
        XCTAssertEqual(volume, 8.0, accuracy: 0.01, "el modelo no se muta si la feature falla")
        XCTAssertFalse(controller.statusMessage.isEmpty, "el fallo se comunica en statusMessage")
    }
}
