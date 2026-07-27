import XCTest
@testable import AppForgeStudio

/// Contrato de DESHACER: siempre se deshace lo ÚLTIMO que hizo el usuario.
///
/// Por qué existe (auditoría 2026-07-25): la app tiene dos historiales —
/// `BRepHistory` (features, push/pull) y `CanvasViewModel` (añadir/borrar
/// cuerpos)— y la regla vieja era "primero el B-rep si tiene algo". Eso produce
/// un defecto que cualquiera nota en 10 segundos de uso:
///
///   1. redondeas un cuerpo        → queda en BRepHistory
///   2. añades una primitiva       → queda en el historial de escena
///   3. Deshacer                   → te DES-REDONDEA el cuerpo (!)
///
/// en vez de quitar la primitiva que acabas de crear. Un undo que no deshace lo
/// último es lo más anti-intuitivo que puede hacer un CAD.
@MainActor
final class UndoCoordinatorTests: XCTestCase {

    // MARK: - El caso que motivó el arreglo

    func testUndoPicksSceneWhenSceneOpIsMoreRecent() {
        // Fillet (marca 1), luego añadir primitiva (marca 2).
        XCTAssertEqual(UndoCoordinator.undoTarget(brepSeq: 1, sceneSeq: 2), .scene,
            "lo último fue añadir el cuerpo: Deshacer debe quitarlo, no des-redondear")
    }

    func testUndoPicksBrepWhenBrepOpIsMoreRecent() {
        // Añadir primitiva (marca 1), luego fillet (marca 2).
        XCTAssertEqual(UndoCoordinator.undoTarget(brepSeq: 2, sceneSeq: 1), .brep,
            "lo último fue el fillet: Deshacer debe deshacerlo")
    }

    // MARK: - Historiales vacíos

    func testUndoWithOnlyBrepHistory() {
        XCTAssertEqual(UndoCoordinator.undoTarget(brepSeq: 7, sceneSeq: nil), .brep)
    }

    func testUndoWithOnlySceneHistory() {
        XCTAssertEqual(UndoCoordinator.undoTarget(brepSeq: nil, sceneSeq: 7), .scene)
    }

    func testUndoWithNothingToUndo() {
        XCTAssertEqual(UndoCoordinator.undoTarget(brepSeq: nil, sceneSeq: nil), .none)
        XCTAssertEqual(UndoCoordinator.redoTarget(brepSeq: nil, sceneSeq: nil), .none)
    }

    // MARK: - Rehacer invierte la regla

    /// Deshacer saca siempre la marca MAYOR, así que las entradas caen al stack de
    /// rehacer en orden decreciente: la última en caer —la que toca devolver
    /// primero— es la MENOR.
    func testRedoPicksSmallestSeq() {
        XCTAssertEqual(UndoCoordinator.redoTarget(brepSeq: 2, sceneSeq: 1), .scene,
            "se deshizo primero el 2 y después el 1 → rehacer devuelve el 1")
        XCTAssertEqual(UndoCoordinator.redoTarget(brepSeq: 1, sceneSeq: 2), .brep)
    }

    // MARK: - Secuencia completa (el guion del usuario)

    /// Simula deshacer/rehacer alternando historiales y comprueba que el orden es
    /// exactamente el inverso al de ejecución — la propiedad que define un undo.
    func testFullSequenceUndoesInReverseOrder() {
        // El usuario hace: escena(1) → brep(2) → escena(3).
        var brepUndo: [UInt64] = [2]
        var sceneUndo: [UInt64] = [1, 3]
        var brepRedo: [UInt64] = []
        var sceneRedo: [UInt64] = []
        var order: [UInt64] = []

        for _ in 0..<3 {
            switch UndoCoordinator.undoTarget(brepSeq: brepUndo.last, sceneSeq: sceneUndo.last) {
            case .brep:
                let s = brepUndo.removeLast(); brepRedo.append(s); order.append(s)
            case .scene:
                let s = sceneUndo.removeLast(); sceneRedo.append(s); order.append(s)
            case .sketch:
                XCTFail("este guion no alimenta el historial de dibujo")
            case .none:
                XCTFail("quedaban operaciones por deshacer")
            }
        }

        XCTAssertEqual(order, [3, 2, 1],
            "deshacer va estrictamente en orden inverso al de ejecución")

        // Y rehacer las devuelve en el orden original.
        var redone: [UInt64] = []
        for _ in 0..<3 {
            switch UndoCoordinator.redoTarget(brepSeq: brepRedo.last, sceneSeq: sceneRedo.last) {
            case .brep:   redone.append(brepRedo.removeLast())
            case .scene:  redone.append(sceneRedo.removeLast())
            case .sketch: XCTFail("el dibujo no tiene pila de rehacer")
            case .none:   XCTFail("quedaban operaciones por rehacer")
            }
        }
        XCTAssertEqual(redone, [1, 2, 3],
            "rehacer reconstruye el orden original de ejecución")
    }

    // MARK: - El DIBUJO entra en el arbitraje

    /// El historial del dibujo estaba fuera del coordinador, así que «Deshacer»
    /// nunca podía borrar un trazo y parecía operar solo sobre el 3D — reportado
    /// en device. Con su marca, gana cuando es lo más reciente.
    func testUndoPicksSketchWhenItIsTheMostRecent() {
        XCTAssertEqual(
            UndoCoordinator.undoTarget(brepSeq: 1, sceneSeq: 2, sketchSeq: 3), .sketch,
            "lo último fue dibujar: Deshacer debe borrar el trazo")
    }

    func testSketchLosesWhenSomethingNewerHappened() {
        XCTAssertEqual(
            UndoCoordinator.undoTarget(brepSeq: 9, sceneSeq: 2, sketchSeq: 3), .brep)
        XCTAssertEqual(
            UndoCoordinator.undoTarget(brepSeq: 1, sceneSeq: 9, sketchSeq: 3), .scene)
    }

    func testOnlySketchHistory() {
        XCTAssertEqual(
            UndoCoordinator.undoTarget(brepSeq: nil, sceneSeq: nil, sketchSeq: 4), .sketch)
    }

    // MARK: - El reloj

    func testClockIsStrictlyMonotonic() {
        let a = UndoClock.tick()
        let b = UndoClock.tick()
        let c = UndoClock.tick()
        XCTAssertLessThan(a, b)
        XCTAssertLessThan(b, c)
    }
}
