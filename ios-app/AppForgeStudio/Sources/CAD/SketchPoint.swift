import Foundation
import simd

/// Punto de sketch 2D con identidad estable.
///
/// Primitiva COMPARTIDA (no parte del motor de sketch legacy que se retiró): la
/// consumen el solver de restricciones (`GeometryConstraintManager.resolveConstraints(with:)`),
/// el `VertexProvider` de `Mesh`, y el `ConstraintManager`/`WireManager`. Vivía
/// dentro de `CADSketchEngine.swift`; al eliminar ese motor se extrajo aquí para
/// que los consumidores legítimos sigan compilando con un solo dueño del tipo.
struct SketchPoint: Identifiable {
    let id: UUID
    var position: SIMD2<Float>

    init(id: UUID = UUID(), position: SIMD2<Float>) {
        self.id = id
        self.position = position
    }
}
