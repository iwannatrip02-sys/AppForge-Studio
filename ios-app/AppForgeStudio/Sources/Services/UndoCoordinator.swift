import Foundation

/// Reloj monótono compartido por los historiales de deshacer.
///
/// La app tiene DOS historiales que registran cosas distintas:
///   · `BRepHistory` — snapshots de B-rep/malla por modelo (features, push/pull).
///   · `CanvasViewModel` — snapshots de la escena entera (añadir/borrar cuerpos).
///
/// Cada uno sabe deshacer lo suyo, pero ninguno sabe cuál de los dos registró la
/// operación MÁS RECIENTE. Sin esa marca, «Deshacer» tenía que elegir a ciegas y
/// se resolvía con «primero el B-rep si tiene algo» — lo que producía el defecto:
/// redondeas un cuerpo, luego añades una primitiva, pulsas Deshacer... y te
/// des-redondea el cuerpo en vez de quitar la primitiva que acabas de crear.
///
/// Un undo que no deshace lo último es lo más anti-intuitivo que puede hacer un
/// CAD. Con una marca monótona por entrada, la decisión pasa a ser trivial y
/// correcta: deshace quien tenga la marca mayor.
/// `@MainActor` a propósito: los dos historiales que lo usan (`BRepHistory` y
/// `CanvasViewModel`) ya viven en el main actor, así que el contador no necesita
/// sincronización — y así el estado estático mutable es seguro bajo concurrencia
/// estricta de Swift 6.
@MainActor
enum UndoClock {
    private static var counter: UInt64 = 0

    /// Marca la siguiente operación. Monótona y estrictamente creciente.
    static func tick() -> UInt64 {
        counter &+= 1
        return counter
    }
}

/// A qué historial le toca atender la acción.
enum UndoTarget: Equatable {
    case brep
    case scene
    case none
}

/// Decisión PURA de a quién le toca deshacer/rehacer. Sin `@MainActor` ni
/// dependencias de UI: testeable en unidad, que es donde debe fijarse el
/// contrato de algo tan fácil de romper.
enum UndoCoordinator {

    /// «Deshacer» va al historial que registró la operación MÁS RECIENTE — la
    /// marca MAYOR. `nil` significa que ese historial está vacío.
    ///
    /// Empate (imposible con el reloj monótono, pero definido igual): gana el
    /// B-rep, que es el de grano más fino.
    static func undoTarget(brepSeq: UInt64?, sceneSeq: UInt64?) -> UndoTarget {
        switch (brepSeq, sceneSeq) {
        case (nil, nil):
            return .none
        case (.some, nil):
            return .brep
        case (nil, .some):
            return .scene
        case let (.some(brep), .some(scene)):
            return brep >= scene ? .brep : .scene
        }
    }

    /// «Rehacer» invierte la regla: hay que rehacer lo que se deshizo ÚLTIMO, y
    /// eso es la entrada con la marca MENOR de los stacks de rehacer.
    ///
    /// Por qué: deshacer siempre saca la marca mayor disponible, así que las
    /// entradas caen al stack de rehacer en orden DECRECIENTE. La última en
    /// caer —la que hay que devolver primero— es la más pequeña.
    static func redoTarget(brepSeq: UInt64?, sceneSeq: UInt64?) -> UndoTarget {
        switch (brepSeq, sceneSeq) {
        case (nil, nil):
            return .none
        case (.some, nil):
            return .brep
        case (nil, .some):
            return .scene
        case let (.some(brep), .some(scene)):
            return brep <= scene ? .brep : .scene
        }
    }
}
