import XCTest
import simd
import OCCTSwift
@testable import AppForgeStudio

/// Contrato de SELECCIÓN OBSOLETA: si el array de modelos cambia bajo la
/// selección, esta se descarta — nunca se opera sobre el cuerpo equivocado.
///
/// `SelectionController.Item` guarda un `modelIndex`, es decir un ÍNDICE en
/// `scene.models`. Ese array cambia de tamaño y orden durante el uso normal:
/// `rebuildGizmoOverlays` retira y vuelve a añadir los overlays "__" en cada
/// cambio de selección o de herramienta. Si se crea un cuerpo mientras hay
/// overlays en escena, al retirarlos ese cuerpo cambia de índice — y la
/// selección pasaba a apuntar a otro SIN AVISAR.
@MainActor
final class SelectionStalenessTests: XCTestCase {

    private func boxModel(_ name: String) throws -> Model {
        let shape = try XCTUnwrap(OCCTSwift.Shape.box(width: 2, height: 2, depth: 2))
        let model = Model(name: name)
        model.cadShape = shape
        model.meshes = [try XCTUnwrap(OCCTBridge.toMesh(shape, quality: .medium))]
        return model
    }

    /// Seleccionar una cara y luego reordenar los modelos invalida la selección
    /// en vez de dejarla apuntando al cuerpo equivocado.
    func testSelectionIsDroppedWhenModelsAreReordered() throws {
        let a = try boxModel("A")
        let b = try boxModel("B")
        var models = [a, b]

        let controller = SelectionController()
        // Tap sobre el cuerpo de índice 1 (B).
        let hit = SurfaceHit(modelIndex: 1, position: SIMD3<Float>(0, 0, 1),
                             normal: SIMD3<Float>(0, 0, 1), distance: 1)
        controller.handleTap(hit: hit, models: models)
        XCTAssertFalse(controller.items.isEmpty, "debe haber seleccionado algo en B")

        // La escena se reordena (p. ej. al retirar overlays intercalados).
        models = [b, a]
        XCTAssertTrue(controller.validate(against: models),
                      "el índice 1 ya no es B: la selección debe invalidarse")
        XCTAssertTrue(controller.items.isEmpty,
                      "mejor perder la selección que operar sobre A creyendo que es B")
    }

    /// Si nada cambió, la selección sobrevive intacta (no-regresión: validar no
    /// puede convertirse en "deseleccionar cada vez que tocas un botón").
    func testSelectionSurvivesWhenModelsAreUnchanged() throws {
        let a = try boxModel("A")
        let models = [a]

        let controller = SelectionController()
        let hit = SurfaceHit(modelIndex: 0, position: SIMD3<Float>(0, 0, 1),
                             normal: SIMD3<Float>(0, 0, 1), distance: 1)
        controller.handleTap(hit: hit, models: models)
        let before = controller.items

        XCTAssertFalse(controller.validate(against: models),
                       "sin cambios no hay nada que invalidar")
        XCTAssertEqual(controller.items, before, "la selección se conserva")
    }

    /// El cuerpo escalado también se valida.
    func testEscalatedBodyIsDroppedWhenItsIndexNoLongerMatches() throws {
        let a = try boxModel("A")
        let b = try boxModel("B")
        var models = [a, b]

        let controller = SelectionController()
        controller.selectBodyFromPanel(index: 1, models: models)
        XCTAssertEqual(controller.bodyIndex, 1)

        models = [b, a]
        XCTAssertTrue(controller.validate(against: models))
        XCTAssertNil(controller.bodyIndex,
                     "el cuerpo escalado apuntaba a B y el índice 1 ya no es B")
    }

    /// Si el cuerpo desaparece de la escena, la selección tampoco sobrevive.
    func testSelectionIsDroppedWhenModelIsRemoved() throws {
        let a = try boxModel("A")
        let b = try boxModel("B")
        var models = [a, b]

        let controller = SelectionController()
        controller.selectBodyFromPanel(index: 1, models: models)

        models = [a]                        // B eliminado
        XCTAssertTrue(controller.validate(against: models))
        XCTAssertNil(controller.bodyIndex)
    }
}
