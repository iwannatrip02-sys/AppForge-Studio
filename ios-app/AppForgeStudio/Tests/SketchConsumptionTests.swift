import XCTest
import simd
import OCCTSwift
import SketchKernel
@testable import AppForgeStudio

/// Contrato de CONSUMO DEL BOCETO: extruir se lleva SOLO el perfil extruido.
///
/// La UI llamaba a `sketch.clear()` después de extruir, que borra el dibujo
/// ENTERO. Con dos perfiles dibujados extruías uno y el otro desaparecía sin
/// dejar rastro — reportado en device: "desaparece uno de los dibujos y extruye
/// el otro".
@MainActor
final class SketchConsumptionTests: XCTestCase {

    /// Dibuja dos círculos separados; devuelve el controlador.
    private func twoCircles() -> SketchController {
        let s = SketchController()
        s.beginTool(.circle)
        s.tap(at: SIMD2(0, 0))
        s.tap(at: SIMD2(2, 0))          // círculo grande, R=2
        s.beginTool(.circle)
        s.tap(at: SIMD2(10, 0))
        s.tap(at: SIMD2(10.5, 0))       // círculo pequeño, R=0.5
        return s
    }

    func testTwoCirclesProduceTwoRegions() {
        let s = twoCircles()
        XCTAssertEqual(s.entities.count, 2, "dos círculos dibujados")
        XCTAssertEqual(s.regions.count, 2, "cada uno encierra su región")
    }

    /// Consumir el perfil extruido deja el OTRO dibujo en pie.
    func testConsumingExtrudedProfileKeepsTheOtherDrawing() throws {
        let s = twoCircles()
        let consumed = s.activeRegionBoundaryForConsumption()
        XCTAssertFalse(consumed.isEmpty,
                       "la región activa debe traer procedencia de curvas")

        _ = try XCTUnwrap(s.extrudeProfile(height: 1.0))
        s.consumeCurves(of: consumed)

        XCTAssertEqual(s.entities.count, 1,
                       "solo desaparece el perfil que se convirtió en sólido")
        XCTAssertEqual(s.regions.count, 1,
                       "el otro dibujo sigue siendo una región extruible")
    }

    /// Y lo que queda es el círculo PEQUEÑO: se extruyó el de mayor área.
    func testTheSurvivorIsTheOneNotExtruded() throws {
        let s = twoCircles()
        let consumed = s.activeRegionBoundaryForConsumption()
        _ = try XCTUnwrap(s.extrudeProfile(height: 1.0))
        s.consumeCurves(of: consumed)

        let survivor = try XCTUnwrap(s.regions.first)
        // Área del círculo pequeño (R=0.5) ≈ 0.785; el grande (R=2) ≈ 12.57.
        XCTAssertEqual(survivor.area, Double.pi * 0.25, accuracy: 0.05,
                       "sobrevive el círculo pequeño, que no se extruyó")
    }

    /// Con contorno vacío no borra nada: preferible a borrar de más.
    func testEmptyBoundaryConsumesNothing() {
        let s = twoCircles()
        s.consumeCurves(of: [])
        XCTAssertEqual(s.entities.count, 2, "sin procedencia no se toca el dibujo")
    }

    /// Un solo perfil: tras extruir y consumir, el boceto queda vacío — el
    /// comportamiento de antes, que era correcto para el caso de un dibujo.
    func testSingleProfileLeavesSketchEmpty() throws {
        let s = SketchController()
        s.beginTool(.circle)
        s.tap(at: SIMD2(0, 0))
        s.tap(at: SIMD2(1, 0))

        let consumed = s.activeRegionBoundaryForConsumption()
        _ = try XCTUnwrap(s.extrudeProfile(height: 1.0))
        s.consumeCurves(of: consumed)

        XCTAssertTrue(s.entities.isEmpty, "con un solo perfil, el boceto queda limpio")
    }
}
