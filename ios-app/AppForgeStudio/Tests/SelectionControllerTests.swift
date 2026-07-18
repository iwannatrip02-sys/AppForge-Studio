import XCTest
import simd
import OCCTSwift
@testable import AppForgeStudio

/// Tests de la selección DIRECTA v2 (feedback device: "sin pasar por cuerpo,
/// en tiempo real, multi"): un tap = cara/arista tocada; taps suman; tocar lo
/// seleccionado lo quita; "Cuerpo" escala; vacío deselecciona.
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

    func testSingleTapSelectsFaceDirectly() throws {
        let model = try makeBoxModel()
        let sel = SelectionController()
        sel.handleTap(hit: hit(SIMD3<Float>(0, 0, 1)), models: [model])   // centro cara +Z

        guard case .face(0, _)? = sel.lastItem else {
            return XCTFail("UN tap en el centro de una cara la selecciona DIRECTO, es \(String(describing: sel.lastItem))")
        }
        XCTAssertNotNil(sel.highlightMesh)
        XCTAssertTrue(sel.statusMessage.contains("4.00"), "área exacta en vivo: \(sel.statusMessage)")
    }

    func testSingleTapNearEdgeSelectsEdgeDirectly() throws {
        let model = try makeBoxModel()
        let sel = SelectionController()
        sel.handleTap(hit: hit(SIMD3<Float>(1, 0, 1)), models: [model])   // arista x=1,z=1

        guard case .edge(0, _)? = sel.lastItem else {
            return XCTFail("UN tap sobre la arista la selecciona DIRECTO")
        }
        XCTAssertTrue(sel.statusMessage.contains("2.00"), "longitud exacta: \(sel.statusMessage)")
    }

    func testMultiSelectionAccumulatesAndToggles() throws {
        let model = try makeBoxModel()
        let sel = SelectionController()
        let faceA = hit(SIMD3<Float>(0, 0, 1))      // cara +Z
        let faceB = hit(SIMD3<Float>(1, 0, 0))      // cara +X (centro)

        sel.handleTap(hit: faceA, models: [model])
        sel.handleTap(hit: faceB, models: [model])
        XCTAssertEqual(sel.items.count, 2, "los taps SUMAN (multi-selección)")
        XCTAssertTrue(sel.statusMessage.contains("2 caras"), "estado: \(sel.statusMessage)")
        XCTAssertTrue(sel.statusMessage.contains("8.00"), "área total 4+4: \(sel.statusMessage)")

        sel.handleTap(hit: faceB, models: [model])
        XCTAssertEqual(sel.items.count, 1, "tocar lo seleccionado lo QUITA")
    }

    func testEscalateToBody() throws {
        let model = try makeBoxModel()
        let sel = SelectionController()
        sel.handleTap(hit: hit(SIMD3<Float>(0, 0, 1)), models: [model])
        sel.escalateToBody(models: [model])

        XCTAssertEqual(sel.bodyIndex, 0)
        XCTAssertTrue(sel.items.isEmpty, "escalar limpia los items")
        XCTAssertEqual(sel.outlinedModelId, model.id.uuidString, "cuerpo → outline")
        XCTAssertTrue(sel.statusMessage.contains("8.00"), "volumen exacto: \(sel.statusMessage)")
    }

    func testDeselectClearsEverything() throws {
        let model = try makeBoxModel()
        let sel = SelectionController()
        sel.handleTap(hit: hit(SIMD3<Float>(0, 0, 1)), models: [model])
        sel.escalateToBody(models: [model])
        sel.deselect()

        XCTAssertTrue(sel.items.isEmpty)
        XCTAssertNil(sel.bodyIndex)
        XCTAssertNil(sel.highlightMesh)
        XCTAssertNil(sel.outlinedModelId)
    }

    // MARK: - Selección de CUERPO entre varios (bloqueador T0)

    /// Con DOS cuerpos, el picking de escena elige el MÁS CERCANO al ojo y la
    /// selección recae sobre ESE cuerpo. Espejo de ScenePickingTests pero de
    /// punta a punta (rayo → hit → SelectionController.handleTap).
    func testTapSelectsNearestBodyOfTwo() throws {
        let near = try makeBoxModel()   // caja centrada [-1,1]³
        let far = try makeBoxModel()
        // Aleja el segundo en -Z (más lejos de la cámara cenital en z=10).
        for i in far.meshes[0].vertices.indices {
            far.meshes[0].vertices[i].position.z -= 5
        }
        let camera = Scene3D.Camera(position: SIMD3<Float>(0, 0, 10),
                                    target: SIMD3<Float>(0, 0, 0),
                                    up: SIMD3<Float>(0, 1, 0),
                                    fov: 45, nearPlane: 0.1, farPlane: 100)
        let ray = CameraRay.from(screenPoint: CGPoint(x: 200, y: 200),
                                 viewSize: CGSize(width: 400, height: 400),
                                 camera: camera)
        let models = [far, near]   // el cercano es el índice 1
        let hit = try XCTUnwrap(ScenePicker.hitTest(models: models, ray: ray))
        XCTAssertEqual(hit.modelIndex, 1, "picking elige el cuerpo más cercano al ojo")

        let sel = SelectionController()
        sel.handleTap(hit: hit, models: models)
        XCTAssertEqual(sel.lastItem?.modelIndex, 1,
                       "la selección recae sobre el cuerpo cercano")
        XCTAssertNotNil(sel.highlightMesh, "feedback visual inequívoco (highlight)")
    }

    /// Tocar otro cuerpo CAMBIA la selección al escalar a cuerpo; tap en vacío
    /// (deselect) la limpia. Cubre "tap en otro cuerpo → cambia; vacío → nada".
    func testBodySelectionSwitchesAndClears() throws {
        let a = try makeBoxModel()
        let b = try makeBoxModel()
        let sel = SelectionController()

        sel.handleTap(hit: hit(SIMD3<Float>(0, 0, 1), model: 0), models: [a, b])
        sel.escalateToBody(models: [a, b])
        XCTAssertEqual(sel.bodyIndex, 0)

        sel.handleTap(hit: hit(SIMD3<Float>(0, 0, 1), model: 1), models: [a, b])
        sel.escalateToBody(models: [a, b])
        XCTAssertEqual(sel.bodyIndex, 1, "tocar otro cuerpo cambia la selección")

        sel.deselect()
        XCTAssertNil(sel.bodyIndex, "tap en vacío deselecciona")
        XCTAssertNil(sel.outlinedModelId)
    }

    func testMeshOnlyModelReportsVisibleState() {
        let model = Model(name: "Escultura")
        var mesh = Mesh(vertices: [], indices: [])
        mesh.vertices = [Vertex(position: .zero, normal: SIMD3<Float>(0, 0, 1), uv: .zero)]
        model.meshes = [mesh]
        let sel = SelectionController()
        sel.handleTap(hit: hit(.zero), models: [model])
        XCTAssertTrue(sel.statusMessage.contains("malla libre"),
                      "estado VISIBLE, nunca silencio: \(sel.statusMessage)")
    }
}
