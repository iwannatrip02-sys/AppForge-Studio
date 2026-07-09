import XCTest
import simd
import OCCTSwift
@testable import AppForgeStudio

/// Tests del sistema de selección unificado (ÁREA 1): cuerpo → cara/arista
/// con refinamiento por segundo tap, deselección, y estados siempre visibles.
@MainActor
final class SelectionControllerTests: XCTestCase {

    private func makeBoxModel() throws -> Model {
        let shape = try XCTUnwrap(OCCTSwift.Shape.box(width: 2, height: 2, depth: 2))
        let mesh = try XCTUnwrap(OCCTBridge.toMesh(shape, quality: .medium))
        let model = Model(name: "SelBox")
        model.cadShape = shape
        model.meshes = [mesh]
        return model
    }

    private func hit(_ p: SIMD3<Float>, model: Int = 0) -> SurfaceHit {
        SurfaceHit(modelIndex: model, position: p, normal: SIMD3<Float>(0, 0, 1), distance: 1)
    }

    func testFirstTapSelectsBody() throws {
        let model = try makeBoxModel()
        let sel = SelectionController()

        sel.handleTap(hit: hit(SIMD3<Float>(0, 0, 1)), models: [model])
        XCTAssertEqual(sel.selection, .body(modelIndex: 0))
        XCTAssertEqual(sel.outlinedModelId, model.id.uuidString, "el cuerpo se marca para outline")
        XCTAssertNil(sel.highlightMesh, "cuerpo = outline del renderer, sin overlay de malla")
        XCTAssertFalse(sel.statusMessage.isEmpty)
    }

    func testSecondTapOnFaceCenterRefinesToFace() throws {
        let model = try makeBoxModel()
        let sel = SelectionController()
        let faceCenter = hit(SIMD3<Float>(0, 0, 1))

        sel.handleTap(hit: faceCenter, models: [model])
        sel.handleTap(hit: faceCenter, models: [model])
        guard case .face(0, _)? = sel.selection else {
            return XCTFail("el 2º tap en el centro de una cara debe refinar a CARA, es \(String(describing: sel.selection))")
        }
        XCTAssertNotNil(sel.highlightMesh, "la cara seleccionada tiene highlight")
        XCTAssertNil(sel.outlinedModelId, "al refinar, el outline de cuerpo se apaga")
    }

    func testSecondTapNearEdgeRefinesToEdge() throws {
        let model = try makeBoxModel()
        let sel = SelectionController()
        let edgePoint = hit(SIMD3<Float>(1, 0, 1))  // punto medio de la arista x=1,z=1

        sel.handleTap(hit: edgePoint, models: [model])
        sel.handleTap(hit: edgePoint, models: [model])
        guard case .edge(0, _)? = sel.selection else {
            return XCTFail("el 2º tap sobre una arista debe refinar a ARISTA")
        }
        XCTAssertNotNil(sel.highlightMesh, "la arista seleccionada tiene tubo de highlight")
    }

    func testMeshOnlyModelReportsVisibleState() {
        let model = Model(name: "Escultura")  // sin cadShape
        var mesh = Mesh(vertices: [], indices: [])
        mesh.vertices = [Vertex(position: .zero, normal: SIMD3<Float>(0, 0, 1), uv: .zero)]
        model.meshes = [mesh]
        let sel = SelectionController()
        let p = hit(.zero)

        sel.handleTap(hit: p, models: [model])   // cuerpo ✓
        sel.handleTap(hit: p, models: [model])   // refinar → sin B-rep
        XCTAssertEqual(sel.selection, .body(modelIndex: 0), "sin B-rep se queda en cuerpo")
        XCTAssertTrue(sel.statusMessage.contains("malla libre"),
                      "el estado es VISIBLE, nunca silencio (feedback: 'la esfera muda')")
    }

    func testDeselectClearsEverything() throws {
        let model = try makeBoxModel()
        let sel = SelectionController()
        sel.handleTap(hit: hit(SIMD3<Float>(0, 0, 1)), models: [model])

        sel.deselect()
        XCTAssertNil(sel.selection)
        XCTAssertNil(sel.outlinedModelId)
        XCTAssertNil(sel.highlightMesh)
        XCTAssertNil(sel.lastHit)
    }
}
