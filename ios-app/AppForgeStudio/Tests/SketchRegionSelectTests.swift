import XCTest
import simd
import SketchKernel
@testable import AppForgeStudio

/// LA mecánica Shapr3D: tap DENTRO de una región cerrada la selecciona; el
/// drag desde adentro extruye. Fase 1: las regiones vienen del kernel
/// (RegionFinder) — más robustas que el detector viejo (cruces reales).
@MainActor
final class SketchRegionSelectTests: XCTestCase {

    private func circleSketch(center: SIMD2<Float> = .zero,
                              radiusPoint: SIMD2<Float> = SIMD2(1, 0)) -> SketchController {
        let s = SketchController()
        s.beginTool(.circle)
        s.tap(at: center)
        s.tap(at: radiusPoint)
        return s
    }

    func testTapInsideCircleSelectsRegion() {
        let s = circleSketch()
        XCTAssertTrue(s.selectRegion(at: SIMD2(0.2, 0.1)))
        XCTAssertNotNil(s.selectedRegion)
    }

    func testTapOutsideDoesNotSelect() {
        let s = circleSketch()
        XCTAssertFalse(s.selectRegion(at: SIMD2(5, 5)))
        XCTAssertNil(s.selectedRegion)
    }

    func testSmallestContainingRegionWins() {
        // Círculo DENTRO de un rectángulo: tocar dentro del círculo elige el
        // círculo. (El círculo se dibuja PRIMERO: tap dentro de una región
        // existente la selecciona — la mecánica pedida en device 2026-07-13 —
        // así que lo interior se dibuja antes, o por drag.)
        let s = SketchController()
        s.beginTool(.circle)
        s.tap(at: SIMD2(0, 0))
        s.tap(at: SIMD2(1, 0))
        s.beginTool(.rectangle)
        s.tap(at: SIMD2(-3, -3))
        s.tap(at: SIMD2(3, 3))
        XCTAssertEqual(s.regions.count, 2)

        let verts = s.region(at: SIMD2(0.1, 0.1))
        XCTAssertNotNil(verts)
        // El polígono del círculo tiene muchos vértices pero área ~π
        let area = zip(verts!, verts!.dropFirst() + [verts![0]])
            .reduce(Float(0)) { $0 + ($1.0.x * $1.1.y - $1.1.x * $1.0.y) } / 2
        XCTAssertEqual(abs(area), .pi, accuracy: 0.1,
                       "tocar dentro del círculo elige el círculo, no el rect")
    }

    func testLineThroughCircleMakesTwoSelectableRegions() {
        // La línea que CRUZA el círculo lo parte en dos medias lunas — el
        // detector viejo no podía; el kernel particiona en los cruces.
        let s = SketchController()
        s.beginTool(.circle)
        s.tap(at: SIMD2(0, 0))
        s.tap(at: SIMD2(2, 0))
        s.beginTool(.line)
        s.tap(at: SIMD2(-2.5, 0))
        s.tap(at: SIMD2(2.5, 0))
        s.beginTool(.circle) // cierra el borrador de línea
        XCTAssertEqual(s.regions.count, 2, "el diámetro parte el disco en dos")
        XCTAssertNotNil(s.region(at: SIMD2(0, 1)), "media luna superior tocable")
        XCTAssertNotNil(s.region(at: SIMD2(0, -1)), "media luna inferior tocable")
    }

    func testDeselect() {
        let s = circleSketch()
        s.selectRegion(at: SIMD2(0.1, 0))
        s.deselectRegion()
        XCTAssertNil(s.selectedRegion)
    }
}
