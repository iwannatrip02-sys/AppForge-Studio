import XCTest
import simd
@testable import AppForgeStudio

/// Contrato de ORDEN DE ESCENA: los overlays de UI viven siempre en la COLA, y
/// los índices de los cuerpos reales son append-only.
///
/// Es el mecanismo que hacía que la selección apuntara al cuerpo equivocado.
/// La selección, el objetivo de transformación y el preview en vivo guardan un
/// `modelIndex` — un ÍNDICE en `scene.models`. Los overlays (`__gizmo*`,
/// `__faceHighlight`, `__livePreview`…) se retiran y se vuelven a añadir en cada
/// cambio de selección o de herramienta, y `removeAll` desplaza todo lo que
/// venga después. Un cuerpo real creado DETRÁS de un overlay cambiaba de índice
/// al retirarlo, en silencio.
@MainActor
final class OverlayOrderingTests: XCTestCase {

    private func body(_ name: String) -> Model { Model(name: name) }
    private func overlay(_ name: String) -> Model { Model(name: name) }

    /// Un cuerpo añadido con overlays presentes se coloca ANTES de ellos.
    func testRealBodyIsInsertedBeforeOverlays() {
        var scene = Scene3D()
        scene.addModel(body("Cuerpo A"))
        scene.addModel(overlay("__gizmoX"))
        scene.addModel(overlay("__gizmoY"))
        scene.addModel(body("Cuerpo B"))          // llega con overlays en escena

        let names = scene.models.map { $0.name }
        XCTAssertEqual(names, ["Cuerpo A", "Cuerpo B", "__gizmoX", "__gizmoY"],
                       "los overlays quedan siempre en la cola")
    }

    /// EL caso del bug: retirar los overlays NO mueve a los cuerpos reales.
    func testRemovingOverlaysDoesNotShiftRealBodyIndices() {
        var scene = Scene3D()
        scene.addModel(body("A"))
        scene.addModel(overlay("__gizmoX"))
        scene.addModel(body("B"))                 // creado con overlay presente

        let indexOfBBefore = scene.models.firstIndex { $0.name == "B" }
        scene.models.removeAll { $0.name.hasPrefix("__") }
        let indexOfBAfter = scene.models.firstIndex { $0.name == "B" }

        XCTAssertEqual(indexOfBBefore, indexOfBAfter,
                       "el índice del cuerpo real no puede moverse al retirar overlays")
    }

    /// Ciclo completo de overlays (lo que hace `rebuildGizmoOverlays` en cada
    /// cambio de herramienta): los cuerpos conservan su posición.
    func testOverlayChurnKeepsBodyIndicesStable() {
        var scene = Scene3D()
        scene.addModel(body("A"))
        scene.addModel(body("B"))
        let baseline = scene.models.map { $0.name }

        for _ in 0..<5 {
            scene.addModel(overlay("__gizmoX"))
            scene.addModel(overlay("__faceHighlight"))
            scene.addModel(body("C"))             // un cuerpo nace a mitad del ciclo
            scene.models.removeAll { $0.name.hasPrefix("__") }
            scene.models.removeAll { $0.name == "C" }
        }

        XCTAssertEqual(scene.models.map { $0.name }, baseline,
                       "tras el vaivén de overlays la escena vuelve a su estado")
    }

    /// Los overlays entre sí se añaden en orden de llegada (el renderer los
    /// dibuja en secuencia).
    func testOverlaysKeepInsertionOrderAmongThemselves() {
        var scene = Scene3D()
        scene.addModel(overlay("__gizmoX"))
        scene.addModel(overlay("__gizmoY"))
        scene.addModel(overlay("__gizmoZ"))
        XCTAssertEqual(scene.models.map { $0.name },
                       ["__gizmoX", "__gizmoY", "__gizmoZ"])
    }

    /// Sin overlays, el comportamiento es el de siempre: append (no-regresión).
    func testWithoutOverlaysItIsPlainAppend() {
        var scene = Scene3D()
        scene.addModel(body("A"))
        scene.addModel(body("B"))
        scene.addModel(body("C"))
        XCTAssertEqual(scene.models.map { $0.name }, ["A", "B", "C"])
    }
}
