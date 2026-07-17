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

    // MARK: - Estado NEUTRAL vs ARMADO (beta 2026-07-16b)

    /// BUG crítico: trazar A→B con la herramienta línea ARMADA y arrastrar desde
    /// B debe crear una NUEVA línea B→C, sin mover B (antes el drag secuestraba
    /// el gesto para mover el punto). A y B quedan intactas.
    func testArmedDragFromEndpointDrawsNewLineKeepingPreviousIntact() {
        let s = SketchController()
        s.beginTool(.line)
        // A→B por drag
        s.pencilDragBegan(at: SIMD2(0, 0))
        s.pencilDragEnded(at: SIMD2(2, 0))
        XCTAssertEqual(s.entities.count, 1)
        // Drag DESDE B (extremo) hacia C: armada → dibuja, no mueve B
        s.pencilDragBegan(at: SIMD2(2.02, 0.01))   // el snap arranca EXACTO en B
        s.pencilDragEnded(at: SIMD2(2, 2))
        XCTAssertEqual(s.entities.count, 2, "se creó una línea NUEVA B→C")
        XCTAssertEqual(s.model.positions.count, 3,
                       "A, B (compartido) y C — B no se movió, se reusó")
        // A sigue en (0,0), B sigue en (2,0)
        XCTAssertNotNil(s.model.existingPoint(near: Vec2(0, 0), tolerance: 0.05),
                        "A intacto en (0,0)")
        XCTAssertNotNil(s.model.existingPoint(near: Vec2(2, 0), tolerance: 0.05),
                        "B intacto en (2,0) — NO se arrastró")
        XCTAssertNotNil(s.model.existingPoint(near: Vec2(2, 2), tolerance: 0.05),
                        "C creado en (2,2)")
    }

    /// NEUTRAL: tap sobre un trazo lo AÑADE al set; segundo tap lo QUITA; tap a
    /// otro con uno ya seleccionado → los dos en el set (selección múltiple).
    func testNeutralTapTogglesMultiSelection() {
        let s = SketchController()
        // Dos líneas separadas, luego a neutral
        s.beginTool(.line)
        s.pencilDragBegan(at: SIMD2(0, 0))
        s.pencilDragEnded(at: SIMD2(2, 0))       // línea 1: y≈0
        s.beginTool(.line)
        s.pencilDragBegan(at: SIMD2(0, 3))
        s.pencilDragEnded(at: SIMD2(2, 3))       // línea 2: y≈3
        s.disarm()
        XCTAssertNil(s.armedTool, "en neutral no hay herramienta armada")

        s.tap(at: SIMD2(1, 0))                   // sobre línea 1
        XCTAssertEqual(s.selectedCurveIDs.count, 1)
        s.tap(at: SIMD2(1, 3))                   // sobre línea 2 → ambas
        XCTAssertEqual(s.selectedCurveIDs.count, 2, "selección múltiple")
        s.tap(at: SIMD2(1, 0))                   // de nuevo sobre línea 1 → sale
        XCTAssertEqual(s.selectedCurveIDs.count, 1, "segundo tap deselecciona ese trazo")
    }

    /// NEUTRAL: tap dentro de una región cerrada la selecciona SIN herramienta.
    func testNeutralTapInsideRegionSelectsIt() {
        let s = SketchController()
        s.beginTool(.rectangle)
        s.tap(at: SIMD2(0, 0))
        s.tap(at: SIMD2(4, 4))                   // rect cerrado → auto-neutral
        XCTAssertNil(s.armedTool, "auto-neutral tras cerrar el rectángulo")
        s.tap(at: SIMD2(2, 2))                   // dentro, en neutral
        XCTAssertNotNil(s.selectedRegion, "tap dentro de región la selecciona sin herramienta")
    }

    /// AUTO-NEUTRAL: cerrar un rectángulo por dos taps con `.rectangle` armado
    /// deja el controlador en neutral (`armedTool == nil`).
    func testRectangleAutoDisarmsAfterClose() {
        let s = SketchController()
        s.beginTool(.rectangle)
        XCTAssertEqual(s.armedTool, .rectangle)
        s.tap(at: SIMD2(0, 0))
        s.tap(at: SIMD2(2, 3))
        XCTAssertNil(s.armedTool, "figura cerrada confirmada → neutral")
        XCTAssertEqual(s.entities.count, 4)
    }

    /// AUTO-NEUTRAL: cerrar una cadena de líneas también vuelve a neutral y la
    /// línea permanece armada hasta ese cierre.
    func testLineChainStaysArmedUntilClose() {
        let s = SketchController()
        s.beginTool(.line)
        s.tap(at: SIMD2(0, 0))
        s.tap(at: SIMD2(2, 0))
        s.tap(at: SIMD2(2, 2))
        XCTAssertEqual(s.armedTool, .line, "la cadena abierta sigue armada")
        s.tap(at: SIMD2(0, 2))
        s.tap(at: SIMD2(0.02, 0.02))             // cerrar sobre el primero
        XCTAssertNil(s.armedTool, "cerrar la cadena → neutral")
        XCTAssertEqual(s.regions.count, 1)
    }

    // MARK: - Segunda pasada de regiones (robustez ante gaps)

    /// Un cuadrado con las esquinas desviadas ~0.05 (gaps mayores que la
    /// mergeTolerance de 1e-3) NO cierra en la primera pasada, pero SÍ en la
    /// segunda con weldTolerance = snapRadiusPlane*0.5. Feedback device:
    /// "cerrar cadena todavía no funciona muy bien".
    func testSecondPassClosesDeviatedSquare() {
        let s = SketchController()
        // Radio de snap DIMINUTO durante el trazado: los extremos desviados NO
        // se fusionan por endpoint-snap (quedan como esquinas separadas).
        s.unitsPerPoint = 1e-5

        // 4 lados como líneas independientes (beginTool nuevo = sin cadena), con
        // las esquinas desviadas ~0.05 respecto a un cuadrado 4×4 perfecto.
        func side(_ a: SIMD2<Float>, _ b: SIMD2<Float>) {
            s.beginTool(.line)
            s.pencilDragBegan(at: a)
            s.pencilDragEnded(at: b)
        }
        side(SIMD2(0.00, 0.00), SIMD2(4.05, 0.03))
        side(SIMD2(4.02, 0.05), SIMD2(3.98, 4.04))
        side(SIMD2(4.01, 4.00), SIMD2(0.04, 3.97))
        side(SIMD2(0.03, 4.02), SIMD2(0.02, 0.05))
        s.disarm()

        // Primera pasada (radio diminuto): los gaps ~0.05 no sueldan → 0 regiones.
        XCTAssertTrue(s.regions.isEmpty, "con gaps y radio diminuto no cierra")

        // Zoom que da snapRadiusPlane ≈ 0.3 → weld del 2º pase = 0.15 > gaps.
        s.unitsPerPoint = 0.3 / 22
        s.recomputeRegions()
        XCTAssertEqual(s.regions.count, 1,
                       "la segunda pasada tolerante cierra el cuadrado desviado")
    }

    // MARK: - Radio de snap adaptativo al zoom

    /// Con `unitsPerPoint` grande (zoom lejano) el snap agarra desde MÁS lejos;
    /// con `unitsPerPoint` pequeño (zoom cercano) exige más precisión.
    func testDynamicSnapRadiusScalesWithZoom() {
        let s = SketchController()
        s.beginTool(.line)
        s.tap(at: SIMD2(0, 0))
        s.tap(at: SIMD2(2, 0))                   // extremo en (2,0)
        s.beginTool(.line)

        // Zoom CERCANO: radio pequeño → un cursor a 0.3 del extremo NO engancha.
        s.unitsPerPoint = 0.005                  // radio = 22*0.005 = 0.11
        s.tap(at: SIMD2(2.3, 0))
        XCTAssertNotEqual(s.snapMarker?.kind, .endpoint,
                          "con zoom cercano el snap NO llega a 0.3 de distancia")

        // Zoom LEJANO: radio grande → el mismo cursor SÍ engancha el extremo.
        let s2 = SketchController()
        s2.beginTool(.line)
        s2.tap(at: SIMD2(0, 0))
        s2.tap(at: SIMD2(2, 0))
        s2.beginTool(.line)
        s2.unitsPerPoint = 0.05                  // radio = 22*0.05 = 1.1
        s2.tap(at: SIMD2(2.3, 0))
        XCTAssertEqual(s2.snapMarker?.kind, .endpoint,
                       "con zoom lejano el snap agarra desde más lejos")
    }
}
