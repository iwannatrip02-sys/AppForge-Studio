import XCTest
import simd
@testable import AppForgeStudio

/// LA mecánica Shapr3D (feedback device 2026-07-13: "no puedo seleccionar las
/// figuras para extruirlas, el drag no funciona en nada"): tap DENTRO de una
/// región cerrada la selecciona; el drag desde adentro extruye. Estos tests
/// cubren la capa de selección/prioridad que el cableado de UI usa.
@MainActor
final class SketchRegionSelectTests: XCTestCase {

    private func circleSketch(center: SIMD2<Float> = .zero,
                              radiusPoint: SIMD2<Float> = SIMD2(1, 0)) -> SketchController {
        let s = SketchController()
        s.activeTool = .circle
        s.tap(at: center)       // centro
        s.tap(at: radiusPoint)  // radio
        return s
    }

    func testTapInsideCircleFindsAndSelectsRegion() throws {
        let s = circleSketch()
        XCTAssertNotNil(s.region(at: SIMD2(0.3, 0.2)), "un punto interior encuentra la región del círculo")
        XCTAssertTrue(s.selectRegion(at: SIMD2(0.3, 0.2)))
        XCTAssertNotNil(s.selectedRegion, "la región queda seleccionada (sin añadir geometría)")
        XCTAssertGreaterThanOrEqual(s.selectedRegion?.count ?? 0, 8,
                                    "el círculo discretizado tiene vértices suficientes")
    }

    func testTapOutsideFindsNothingAndDeselects() throws {
        let s = circleSketch()
        XCTAssertTrue(s.selectRegion(at: SIMD2(0.1, 0.1)))
        XCTAssertNil(s.region(at: SIMD2(5, 5)), "fuera del círculo no hay región")
        XCTAssertFalse(s.selectRegion(at: SIMD2(5, 5)))
        XCTAssertNil(s.selectedRegion, "tap fuera deselecciona")
    }

    func testPointPriorityIsTightSoInteriorTapsDoNotDeform() throws {
        // El círculo solo tiene UN punto editable: su centro. Un toque interior
        // lejos del centro NO debe estar "cerca de un punto" (antes el radio de
        // captura amplio hacía que picar adentro deformara la figura).
        let s = circleSketch()
        let dCenter = try XCTUnwrap(s.nearestEditablePointDistance(to: SIMD2(0.05, 0)))
        XCTAssertLessThan(dCenter, SketchController.snapRadius * 0.8,
                          "pegado al centro SÍ es ajuste fino")
        let dInterior = try XCTUnwrap(s.nearestEditablePointDistance(to: SIMD2(0.6, 0)))
        XCTAssertGreaterThan(dInterior, SketchController.snapRadius * 0.8,
                             "un punto interior típico NO captura el punto → va a región")
    }

    func testSelectedRegionExtrudesToRealSolid() throws {
        let s = circleSketch()
        XCTAssertTrue(s.selectRegion(at: SIMD2(0.2, 0.1)))
        let verts = try XCTUnwrap(s.selectedRegion)
        let model = try XCTUnwrap(s.extrudeRegion(vertices: verts, height: 0.8),
                                  "la región seleccionada se extruye a sólido")
        let vol = try XCTUnwrap(model.cadShape?.volume)
        // círculo r=1 discretizado a 32 lados → volumen algo menor que π·r²·h
        XCTAssertEqual(vol, Double.pi * 0.8, accuracy: Double.pi * 0.8 * 0.05,
                       "volumen ≈ π r² h (5% por discretización)")
        XCTAssertNotNil(model.edgesMesh, "el sólido nace con aristas visibles")
    }
}
