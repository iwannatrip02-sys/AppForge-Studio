import XCTest
import simd
import OCCTSwift
@testable import AppForgeStudio

/// Tests del blindaje de booleanos OCCT (`RobustBoolean`): fuzzy tolerance para
/// caras COPLANARES + ShapeFix de rescate. Oráculo = VOLUMEN EXACTO, como el
/// resto de tests B-rep: solo un kernel real puede garantizarlo.
///
/// El caso estrella es el que FreeCAD tardó años en domar: dos cajas pegadas
/// EXACTAMENTE en una cara (caras coincidentes/coplanares). Los operadores
/// crudos +/-/& de OCCT pueden fallar o devolver un sólido inválido ahí; el
/// punto único de paso lo resuelve subiendo la fuzzy tolerance y/o curando con
/// ShapeFix. Si el OCCT del simulador ya lo resuelve sin fuzzy, el test sigue
/// documentando y guardando el contrato (volumen correcto, shape válida).
final class RobustBooleanTests: XCTestCase {

    /// Caja 1×1×1 CENTRADA en el origen → ocupa [-0.5, 0.5]³ (convención OCCT).
    private func unitBox() throws -> CADShape {
        try XCTUnwrap(OCCTSwift.Shape.box(width: 1, height: 1, depth: 1),
                      "la primitiva box debe existir")
    }

    // MARK: - Caras COPLANARES: dos cajas pegadas exactamente en una cara

    /// Dos cajas unitarias adyacentes que COMPARTEN la cara x=0.5 (coplanares).
    /// Unión = un bloque 2×1×1 → volumen 2. Este es el caso que revienta los
    /// booleanos ingenuos sin fuzzy tolerance.
    func testUnionOfCoplanarAdjacentBoxesHasExactVolume() throws {
        let a = try unitBox()
        let b = try XCTUnwrap(try unitBox().translated(by: SIMD3<Double>(1, 0, 0)),
                              "desplazar B en +1X la pega a A en la cara x=0.5")
        let result = try XCTUnwrap(RobustBoolean.union(a, b),
                                   "la unión de dos cajas coplanares debe dar un sólido válido (fuzzy/ShapeFix)")
        XCTAssertTrue(RobustBoolean.isSane(result), "el resultado debe ser topológicamente válido")
        XCTAssertEqual(try XCTUnwrap(result.volume), 2.0, accuracy: 0.01,
                       "1 + 1 sin solape = 2 (bloque 2×1×1)")
    }

    /// Resta con caras coplanares: A menos B adyacente (solo se tocan en la cara,
    /// sin solape de volumen) → A queda intacta, volumen 1.
    func testSubtractOfCoplanarAdjacentBoxKeepsVolume() throws {
        let a = try unitBox()
        let b = try XCTUnwrap(try unitBox().translated(by: SIMD3<Double>(1, 0, 0)))
        let result = try XCTUnwrap(RobustBoolean.subtract(a, b),
                                   "restar una caja que solo toca la cara no debe degenerar")
        XCTAssertTrue(RobustBoolean.isSane(result))
        XCTAssertEqual(try XCTUnwrap(result.volume), 1.0, accuracy: 0.01,
                       "B no solapa volumen con A → A queda entera")
    }

    // MARK: - Booleanos con SOLAPE real (oráculo de volumen exacto)

    func testUnionOverlappingBoxesExactVolume() throws {
        let a = try unitBox()
        // Solape de media unidad en X: unión = 1 + 1 - 0.5 = 1.5
        let b = try XCTUnwrap(try unitBox().translated(by: SIMD3<Double>(0.5, 0, 0)))
        let result = try XCTUnwrap(RobustBoolean.union(a, b))
        XCTAssertEqual(try XCTUnwrap(result.volume), 1.5, accuracy: 0.01)
    }

    func testSubtractOverlappingBoxesExactVolume() throws {
        let a = try unitBox()
        let b = try XCTUnwrap(try unitBox().translated(by: SIMD3<Double>(0.5, 0, 0)))
        // A menos el solape de 0.5 → 1 - 0.5 = 0.5
        let result = try XCTUnwrap(RobustBoolean.subtract(a, b))
        XCTAssertEqual(try XCTUnwrap(result.volume), 0.5, accuracy: 0.01)
    }

    func testIntersectOverlappingBoxesExactVolume() throws {
        let a = try unitBox()
        let b = try XCTUnwrap(try unitBox().translated(by: SIMD3<Double>(0.5, 0, 0)))
        // Solo el solape: 0.5×1×1 = 0.5
        let result = try XCTUnwrap(RobustBoolean.intersect(a, b))
        XCTAssertEqual(try XCTUnwrap(result.volume), 0.5, accuracy: 0.01)
    }

    // MARK: - Contrato de validación

    /// `isSane` debe rechazar exactamente lo que envenena aguas abajo (volumen
    /// no finito) y aceptar un sólido normal.
    func testIsSaneAcceptsValidSolid() throws {
        XCTAssertTrue(RobustBoolean.isSane(try unitBox()),
                      "una caja recién creada es un sólido válido con volumen finito")
    }

    /// El punto único de paso B-rep (BRepModeling.boolean) también pasa por el
    /// blindaje: unión de dos cajas coplanares vía el flujo real de la app.
    func testBRepModelingUnionRoutesThroughRobustBoolean() throws {
        let shapeA = try unitBox()
        let shapeB = try XCTUnwrap(try unitBox().translated(by: SIMD3<Double>(1, 0, 0)))
        let a = Model(name: "A"); a.cadShape = shapeA
        a.meshes = [try XCTUnwrap(OCCTBridge.toMesh(shapeA, quality: .medium))]
        let b = Model(name: "B"); b.cadShape = shapeB
        b.meshes = [try XCTUnwrap(OCCTBridge.toMesh(shapeB, quality: .medium))]

        let result = try XCTUnwrap(BRepModeling.boolean(.booleanUnion, a, b),
                                   "el hub B-rep debe entregar el sólido coplanar unido")
        XCTAssertEqual(try XCTUnwrap(try XCTUnwrap(result.cadShape).volume), 2.0, accuracy: 0.01)
    }
}
