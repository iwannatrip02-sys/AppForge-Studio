import XCTest
import simd
import OCCTSwift
import SketchKernel
@testable import AppForgeStudio

/// Tests del SketchController Fase 1 (adaptador sobre SketchKernel).
/// Mecánicas + oráculos de volumen exactos: el dibujo produce ingeniería.
/// La geometría pura del kernel se fija en SketchKernelTests (host del CI).
@MainActor
final class SketchControllerTests: XCTestCase {

    private func volume(_ model: Model) throws -> Double {
        try XCTUnwrap(try XCTUnwrap(model.cadShape).volume)
    }

    // MARK: - Línea encadenada con topología

    func testLineChainCreatesConnectedTopology() {
        let s = SketchController()
        s.beginTool(.line)
        s.tap(at: SIMD2(0, 0))
        s.tap(at: SIMD2(2, 0))
        s.tap(at: SIMD2(2, 2))
        // 2 segmentos confirmados, esquina COMPARTIDA (3 puntos, no 4)
        XCTAssertEqual(s.entities.count, 2)
        XCTAssertEqual(s.model.positions.count, 3)
    }

    func testClosingChainFormsRegion() {
        let s = SketchController()
        s.beginTool(.line)
        s.tap(at: SIMD2(0, 0))
        s.tap(at: SIMD2(2, 0))
        s.tap(at: SIMD2(2, 2))
        s.tap(at: SIMD2(0, 2))
        s.tap(at: SIMD2(0.02, 0.02))   // cerrar sobre el primer punto
        XCTAssertEqual(s.entities.count, 4, "4 lados")
        XCTAssertEqual(s.regions.count, 1, "el perfil cerrado ES una región")
        XCTAssertTrue(s.hasExtrudableArea)
    }

    func testNoAutomaticChainingAfterBeginTool() {
        let s = SketchController()
        s.beginTool(.line)
        s.tap(at: SIMD2(0, 0))
        s.tap(at: SIMD2(2, 0))
        // Cambiar de herramienta y volver: la cadena NO continúa (bug device)
        s.beginTool(.circle)
        s.beginTool(.line)
        s.tap(at: SIMD2(5, 5))
        XCTAssertEqual(s.entities.count, 1,
                       "el tap tras beginTool inicia cadena nueva, no añade línea")
    }

    // MARK: - Rectángulo / círculo → volúmenes exactos

    func testRectangleByTwoTapsExtrudesExactVolume() throws {
        let s = SketchController()
        s.beginTool(.rectangle)
        s.tap(at: SIMD2(0, 0))
        s.tap(at: SIMD2(2, 3))
        XCTAssertEqual(s.entities.count, 4, "4 líneas reales con esquinas compartidas")
        XCTAssertEqual(s.model.positions.count, 4)
        XCTAssertTrue(s.hasClosedProfile)

        let model = try XCTUnwrap(s.extrudeProfile(height: 1.5))
        XCTAssertEqual(try volume(model), 2 * 3 * 1.5, accuracy: 0.01,
                       "rect 2×3 alto 1.5 → volumen 9.0")
        XCTAssertNotNil(model.edgesMesh, "el sólido nace con aristas visibles")
    }

    func testCircleExtrudesToCylinderVolume() throws {
        let s = SketchController()
        s.beginTool(.circle)
        s.tap(at: SIMD2(0, 0))
        s.tap(at: SIMD2(1, 0))
        XCTAssertEqual(s.regions.count, 1)

        let model = try XCTUnwrap(s.extrudeProfile(height: 2.0))
        XCTAssertEqual(try volume(model), .pi * 2.0, accuracy: 0.05,
                       "cilindro R1 alto 2 → ~2π (perfil poligonal del kernel)")
    }

    // MARK: - Selección (Fase 1 §4: tocar un trazo lo selecciona)

    func testTapOnStrokeSelectsIt() {
        let s = SketchController()
        s.beginTool(.circle)
        s.tap(at: SIMD2(0, 0))
        s.tap(at: SIMD2(2, 0))
        XCTAssertNil(s.selectedCurveID)
        // Tap SOBRE el anillo (no dentro, no en un punto topológico)
        s.tap(at: SIMD2(0, 2.05))
        XCTAssertNotNil(s.selectedCurveID, "tocar el trazo lo selecciona")
    }

    func testTapInEmptinessDeselects() {
        let s = SketchController()
        s.beginTool(.rectangle)
        s.tap(at: SIMD2(0, 0))
        s.tap(at: SIMD2(4, 4))
        s.tap(at: SIMD2(2, 2))          // dentro → selecciona región
        XCTAssertNotNil(s.selectedRegion)
        s.tap(at: SIMD2(20, 20))        // vacío → deselecciona
        XCTAssertNil(s.selectedRegion)
        XCTAssertNil(s.selectedCurveID)
    }

    // MARK: - Arrastre de puntos con topología compartida

    func testDraggingSharedCornerKeepsTopology() {
        let s = SketchController()
        s.beginTool(.line)
        s.tap(at: SIMD2(0, 0))
        s.tap(at: SIMD2(2, 0))
        s.tap(at: SIMD2(2, 2))
        XCTAssertTrue(s.beginDrag(near: SIMD2(2, 0.05)))
        s.drag(to: SIMD2(3, 1))
        s.endDrag()
        let corner = s.model.existingPoint(near: Vec2(3.0, 1.0), tolerance: 0.2)
        XCTAssertNotNil(corner, "la esquina quedó donde se soltó (con snap)")
        XCTAssertEqual(s.model.positions.count, 3, "sigue siendo UN punto compartido")
    }

    // MARK: - Undo

    func testUndoRemovesLastCommit() {
        let s = SketchController()
        s.beginTool(.circle)
        s.tap(at: SIMD2(0, 0))
        s.tap(at: SIMD2(1, 0))
        XCTAssertEqual(s.entities.count, 1)
        s.undoLast()
        XCTAssertEqual(s.entities.count, 0)
        XCTAssertTrue(s.regions.isEmpty)
    }

    // MARK: - Regla anti-placebo

    func testExtrudableAreaMatchesExtrudeCapability() {
        let s = SketchController()
        XCTAssertFalse(s.hasExtrudableArea)
        XCTAssertNil(s.extrudeClosedArea(height: 1.0))

        s.beginTool(.rectangle)
        s.tap(at: SIMD2(0, 0))
        s.tap(at: SIMD2(2, 2))
        XCTAssertTrue(s.hasExtrudableArea)
        XCTAssertNotNil(s.extrudeClosedArea(height: 1.0),
                        "hasExtrudableArea=true implica extrusión real")
    }

    func testOpenPathButtonOnlyWithSpline() {
        let s = SketchController()
        s.beginTool(.line)
        s.tap(at: SIMD2(0, 0))
        s.tap(at: SIMD2(2, 0))
        XCTAssertFalse(s.hasOpenPath, "cadena de líneas NO habilita Tubo (aún)")
        s.beginTool(.spline)
        s.tap(at: SIMD2(0, 1))
        s.tap(at: SIMD2(1, 2))
        s.tap(at: SIMD2(2, 1))
        s.finishSpline()
        XCTAssertTrue(s.hasOpenPath)
        XCTAssertNotNil(s.tubeAlongPath(radius: 0.1))
    }
}
