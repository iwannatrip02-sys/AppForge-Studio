import XCTest
import simd
import OCCTSwift
@testable import AppForgeStudio

/// Tests del pipeline de picking: pantalla → rayo → hit de malla → cara B-rep.
/// Es la columna vertebral de la manipulación directa (tap-en-cara → push/pull).
final class ScenePickingTests: XCTestCase {

    /// Caja OCCT 2×2×2 CENTRADA en el origen (ocupa [-1,1]³ — así la crea OCCTSwift).
    private func makeBoxModel() throws -> Model {
        let shape = try XCTUnwrap(OCCTSwift.Shape.box(width: 2, height: 2, depth: 2))
        let mesh = try XCTUnwrap(OCCTBridge.toMesh(shape, quality: .medium))
        let model = Model(name: "PickBox")
        model.cadShape = shape
        model.meshes = [mesh]
        return model
    }

    private func topDownCamera() -> Scene3D.Camera {
        Scene3D.Camera(position: SIMD3<Float>(0, 0, 10),
                       target: SIMD3<Float>(0, 0, 0),
                       up: SIMD3<Float>(0, 1, 0),
                       fov: 45, nearPlane: 0.1, farPlane: 100)
    }

    // MARK: - CameraRay

    func testCenterScreenRayPointsAtTarget() {
        let camera = topDownCamera()
        let ray = CameraRay.from(screenPoint: CGPoint(x: 200, y: 200),
                                 viewSize: CGSize(width: 400, height: 400),
                                 camera: camera)
        let expected = simd_normalize(camera.target - camera.position)
        XCTAssertLessThan(simd_distance(ray.direction, expected), 1e-4,
                          "el rayo del centro de pantalla apunta al target")
        XCTAssertEqual(ray.origin, camera.position)
    }

    // MARK: - ScenePicker (rayo → malla)

    func testHitTestFindsTopFaceOfBox() throws {
        let model = try makeBoxModel()
        let ray = CameraRay.from(screenPoint: CGPoint(x: 200, y: 200),
                                 viewSize: CGSize(width: 400, height: 400),
                                 camera: topDownCamera())

        let hit = try XCTUnwrap(ScenePicker.hitTest(models: [model], ray: ray),
                                "el rayo cenital debe impactar la caja")
        XCTAssertEqual(hit.modelIndex, 0)
        XCTAssertEqual(hit.position.z, 1.0, accuracy: 0.01,
                       "impacto en la cara superior (z=1, caja centrada), no atravesarla")
        XCTAssertGreaterThan(hit.normal.z, 0.9, "la normal del hit apunta +Z")
    }

    func testHitTestMissesWhenRayPointsAway() throws {
        let model = try makeBoxModel()
        let camera = Scene3D.Camera(position: SIMD3<Float>(0, 0, 10),
                                    target: SIMD3<Float>(0, 0, 20),  // mirando lejos de la caja
                                    up: SIMD3<Float>(0, 1, 0),
                                    fov: 45, nearPlane: 0.1, farPlane: 100)
        let ray = CameraRay.from(screenPoint: CGPoint(x: 200, y: 200),
                                 viewSize: CGSize(width: 400, height: 400),
                                 camera: camera)
        XCTAssertNil(ScenePicker.hitTest(models: [model], ray: ray))
    }

    func testHitTestPicksClosestModel() throws {
        let near = try makeBoxModel()   // [0,2]³
        let far = try makeBoxModel()
        // Alejar el segundo modelo en -Z (más lejos de la cámara cenital en z=10)
        for i in far.meshes[0].vertices.indices {
            far.meshes[0].vertices[i].position.z -= 5
        }
        let ray = CameraRay.from(screenPoint: CGPoint(x: 200, y: 200),
                                 viewSize: CGSize(width: 400, height: 400),
                                 camera: topDownCamera())
        let hit = try XCTUnwrap(ScenePicker.hitTest(models: [far, near], ray: ray))
        XCTAssertEqual(hit.modelIndex, 1, "debe elegir el modelo más cercano a la cámara")
    }

    // MARK: - BRepFacePicker (hit de malla → cara B-rep)

    func testFacePickerMapsTopHitToPlusZFace() throws {
        let model = try makeBoxModel()
        let shape = try XCTUnwrap(model.cadShape)
        let hitPoint = SIMD3<Float>(0, 0, 1)  // centro de la cara superior (caja centrada)

        let idx = try XCTUnwrap(BRepFacePicker.faceIndex(of: shape, nearest: hitPoint))
        let normal = try XCTUnwrap(shape.faces()[idx].normal)
        XCTAssertEqual(abs(normal.z), 1.0, accuracy: 1e-6,
                       "la cara elegida es la del plano Z")
    }

    func testFacePickerRejectsFarPoints() throws {
        let model = try makeBoxModel()
        let shape = try XCTUnwrap(model.cadShape)
        XCTAssertNil(BRepFacePicker.faceIndex(of: shape, nearest: SIMD3<Float>(50, 50, 50)),
                     "un punto lejos de toda cara no debe seleccionar nada")
    }
}
