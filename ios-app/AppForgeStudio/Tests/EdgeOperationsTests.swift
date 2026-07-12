import XCTest
import simd
import OCCTSwift
@testable import AppForgeStudio

/// Tanda de solidez 2026-07-12: fillet/chaflán multi-arista reales y vaciado con
/// dirección — los bugs confirmados en el barrido device del 2026-07-11.
@MainActor
final class EdgeOperationsTests: XCTestCase {

    private func makeBoxModel() throws -> Model {
        let shape = try XCTUnwrap(OCCTSwift.Shape.box(width: 2, height: 2, depth: 2))
        let mesh = try XCTUnwrap(OCCTBridge.toMesh(shape, quality: .medium))
        let model = Model(name: "EBox")
        model.cadShape = shape
        model.meshes = [mesh]
        return model
    }

    func testFilletEdgesRoundsAllSelected() throws {
        let model = try makeBoxModel()
        let before = try XCTUnwrap(model.cadShape?.volume)
        XCTAssertEqual(model.cadShape?.edges().count, 12)
        // Tres aristas a la vez (bug device: solo se redondeaba la última)
        XCTAssertTrue(BRepModeling.filletEdges(model, edgeIndices: [0, 1, 2], radius: 0.15))
        let after = try XCTUnwrap(model.cadShape?.volume)
        XCTAssertLessThan(after, before, "el fillet quita material")
        // Con 3 aristas debe quitar MÁS material que con 1 sola (múltiple real)
        let single = try makeBoxModel()
        XCTAssertTrue(BRepModeling.filletEdges(single, edgeIndices: [0], radius: 0.15))
        let afterSingle = try XCTUnwrap(single.cadShape?.volume)
        XCTAssertLessThan(after, afterSingle, "3 aristas quitan más material que 1")
    }

    func testChamferEdgesIsRealPerEdge() throws {
        let model = try makeBoxModel()
        let before = try XCTUnwrap(model.cadShape?.volume)
        XCTAssertTrue(BRepModeling.chamferEdges(model, edgeIndices: [0, 1], distance: 0.2))
        let after = try XCTUnwrap(model.cadShape?.volume)
        XCTAssertLessThan(after, before, "el chaflán corta material de las aristas elegidas")
    }

    func testChamferRejectsInvalidIndices() throws {
        let model = try makeBoxModel()
        XCTAssertFalse(BRepModeling.chamferEdges(model, edgeIndices: [99], distance: 0.1),
                       "índice fuera de rango no debe mutar nada")
        XCTAssertFalse(BRepModeling.chamferEdges(model, edgeIndices: [], distance: 0.1),
                       "sin aristas no hay operación")
    }

    func testShellInwardKeepsOuterContour() throws {
        let model = try makeBoxModel()
        XCTAssertTrue(BRepModeling.shell(model, thickness: 0.1))
        let maxX = model.meshes[0].vertices.map { abs($0.position.x) }.max() ?? 0
        XCTAssertEqual(maxX, 1.0, accuracy: 0.02,
                       "hacia ADENTRO (default CAD): el contorno exterior NO crece")
    }

    func testShellOutwardGrowsContour() throws {
        let model = try makeBoxModel()
        XCTAssertTrue(BRepModeling.shell(model, thickness: 0.1, outward: true))
        let maxX = model.meshes[0].vertices.map { abs($0.position.x) }.max() ?? 0
        XCTAssertGreaterThan(maxX, 1.05, "hacia AFUERA (opción): la pared crece el grosor")
    }

    func testVertexDotsMeshIsCachedPerGeometryVersion() throws {
        let model = try makeBoxModel()
        let dots = try XCTUnwrap(model.vertexDotsMesh(), "una caja B-rep muestra sus 8 puntos")
        XCTAssertEqual(dots.vertices.count, 8 * 6, "8 esquinas × octaedro de 6 vértices")
        // Misma versión → mismo objeto cacheado (sin recomputar por frame)
        let again = try XCTUnwrap(model.vertexDotsMesh())
        XCTAssertEqual(again.vertices.count, dots.vertices.count)
        // Cambiar la geometría invalida el cache y los puntos siguen las esquinas
        XCTAssertTrue(BRepModeling.chamferEdges(model, edgeIndices: [0], distance: 0.2))
        let after = try XCTUnwrap(model.vertexDotsMesh())
        XCTAssertGreaterThan(after.vertices.count, dots.vertices.count,
                             "el chaflán añade esquinas nuevas → más puntos")
    }
}
