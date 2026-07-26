import XCTest
import simd
import OCCTSwift
@testable import AppForgeStudio

/// Contrato de PICKING BAJO TRANSFORMACIÓN: tocas donde el objeto SE VE.
///
/// `ScenePicker.hitTest` probaba el rayo contra los vértices CRUDOS del modelo,
/// ignorando su `transform`. Mientras el TRS es identidad —el flujo CAD normal,
/// que hornea la transformación al B-rep— daba igual. Pero NO lo es durante el
/// arrastre en vivo, en la reproducción de animación, ni con ensamblajes
/// (`AssemblyMatesEngine` fija rotación de forma persistente). Ahí tocabas donde
/// el objeto se ve y el picking ocurría donde estaba antes.
@MainActor
final class ScenePickingTransformTests: XCTestCase {

    private func boxModel() throws -> Model {
        let shape = try XCTUnwrap(OCCTSwift.Shape.box(width: 2, height: 2, depth: 2))
        let model = Model(name: "Caja")
        model.cadShape = shape
        model.meshes = [try XCTUnwrap(OCCTBridge.toMesh(shape, quality: .medium))]
        return model
    }

    /// Rayo que apunta al centro de un cubo DESPLAZADO: debe acertar.
    func testHitsTranslatedModelWhereItIsDrawn() throws {
        let model = try boxModel()          // ocupa [-1,1]³ en local
        model.position = SIMD3<Float>(10, 0, 0)

        // Rayo desde +X lejano hacia −X, a la altura del cubo desplazado.
        let ray = CameraRay(origin: SIMD3<Float>(20, 0, 0),
                            direction: SIMD3<Float>(-1, 0, 0))
        let hit = try XCTUnwrap(ScenePicker.hitTest(models: [model], ray: ray),
                                "el cubo desplazado debe recibir el toque")
        XCTAssertEqual(hit.modelIndex, 0)
        XCTAssertEqual(hit.position.x, 11, accuracy: 1e-3,
                       "la cara tocada es la del cubo YA desplazado (x = 10 + 1)")
    }

    /// Y el mismo rayo NO debe acertar donde el cubo ya no está.
    func testMissesWhereTheModelUsedToBe() throws {
        let model = try boxModel()
        model.position = SIMD3<Float>(10, 0, 0)

        // Rayo que apunta al ORIGEN, donde estaba antes de desplazarse.
        let ray = CameraRay(origin: SIMD3<Float>(0, 20, 0),
                            direction: SIMD3<Float>(0, -1, 0))
        XCTAssertNil(ScenePicker.hitTest(models: [model], ray: ray),
                     "no debe haber geometría donde el cubo ya no está")
    }

    /// Con ESCALA, la distancia debe medirse en mundo: si no, dos modelos se
    /// ordenarían mal entre sí y el toque elegiría el equivocado.
    func testScaledModelIsHitAtItsScaledSurface() throws {
        let model = try boxModel()
        model.scale = SIMD3<Float>(repeating: 3)   // el cubo pasa a [-3,3]³

        let ray = CameraRay(origin: SIMD3<Float>(20, 0, 0),
                            direction: SIMD3<Float>(-1, 0, 0))
        let hit = try XCTUnwrap(ScenePicker.hitTest(models: [model], ray: ray))
        XCTAssertEqual(hit.position.x, 3, accuracy: 1e-3,
                       "la cara está en x=3 tras escalar ×3, no en x=1")
        XCTAssertEqual(hit.distance, 17, accuracy: 1e-3,
                       "la distancia se mide en MUNDO (20 − 3)")
    }

    /// Gana el que el rayo encuentra ANTES, no el primero de la escena: es la
    /// propiedad que hace que tocar seleccione lo que tienes delante. Con dos
    /// cubos desplazados a distinta X, el orden en el array es irrelevante.
    func testClosestAlongTheRayWinsNotSceneOrder() throws {
        let behind = try boxModel()
        behind.position = SIMD3<Float>(5, 0, 0)    // MÁS LEJOS del origen del rayo
        let inFront = try boxModel()
        inFront.position = SIMD3<Float>(30, 0, 0)  // más cerca del rayo

        // El rayo entra desde x=50 hacia −X: encuentra antes el de x=30.
        let ray = CameraRay(origin: SIMD3<Float>(50, 0, 0),
                            direction: SIMD3<Float>(-1, 0, 0))
        // `behind` va PRIMERO en el array a propósito: si el orden mandara, el
        // resultado sería 0.
        let hit = try XCTUnwrap(ScenePicker.hitTest(models: [behind, inFront], ray: ray))
        XCTAssertEqual(hit.modelIndex, 1, "gana el que el rayo alcanza antes")
        XCTAssertEqual(hit.position.x, 31, accuracy: 1e-3)
    }

    /// Sin transformación el comportamiento es el de siempre (no-regresión).
    func testIdentityTransformBehavesAsBefore() throws {
        let model = try boxModel()
        let ray = CameraRay(origin: SIMD3<Float>(10, 0, 0),
                            direction: SIMD3<Float>(-1, 0, 0))
        let hit = try XCTUnwrap(ScenePicker.hitTest(models: [model], ray: ray))
        XCTAssertEqual(hit.position.x, 1, accuracy: 1e-3)
        XCTAssertEqual(hit.distance, 9, accuracy: 1e-3)
    }
}
