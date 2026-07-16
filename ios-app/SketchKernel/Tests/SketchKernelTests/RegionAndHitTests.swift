import XCTest
@testable import SketchKernel

final class RegionTests: XCTestCase {

    func testSquareIsOneRegion() {
        var m = SketchModel()
        m.addLine(from: Vec2(0, 0), to: Vec2(10, 0))
        m.addLine(from: Vec2(10, 0), to: Vec2(10, 10))
        m.addLine(from: Vec2(10, 10), to: Vec2(0, 10))
        m.addLine(from: Vec2(0, 10), to: Vec2(0, 0))
        let regions = RegionFinder.regions(in: m)
        XCTAssertEqual(regions.count, 1)
        XCTAssertEqual(regions.first?.area ?? 0, 100, accuracy: 1e-6)
        XCTAssertTrue(regions.first?.contains(Vec2(5, 5)) ?? false)
        XCTAssertFalse(regions.first?.contains(Vec2(15, 5)) ?? true)
    }

    func testOpenPolylineHasNoRegions() {
        var m = SketchModel()
        m.addLine(from: Vec2(0, 0), to: Vec2(10, 0))
        m.addLine(from: Vec2(10, 0), to: Vec2(10, 10))
        XCTAssertTrue(RegionFinder.regions(in: m).isEmpty)
    }

    func testCircleIsARegion() {
        var m = SketchModel()
        m.addCircle(center: Vec2(0, 0), radius: 5)
        let regions = RegionFinder.regions(in: m, maxDeviation: 1e-3)
        XCTAssertEqual(regions.count, 1)
        XCTAssertEqual(regions.first?.area ?? 0, .pi * 25, accuracy: 0.2)
        XCTAssertTrue(regions.first?.contains(Vec2(1, 1)) ?? false)
    }

    /// Dos rectángulos que se cruzan: el arreglo debe partir en los cruces y
    /// producir regiones múltiples (el solape es su propia región).
    func testOverlappingRectanglesSplitIntoRegions() {
        var m = SketchModel()
        func rect(_ a: Vec2, _ b: Vec2) {
            m.addLine(from: a, to: Vec2(b.x, a.y))
            m.addLine(from: Vec2(b.x, a.y), to: b)
            m.addLine(from: b, to: Vec2(a.x, b.y))
            m.addLine(from: Vec2(a.x, b.y), to: a)
        }
        rect(Vec2(0, 0), Vec2(10, 10))
        rect(Vec2(5, 5), Vec2(15, 15))
        let regions = RegionFinder.regions(in: m)
        XCTAssertEqual(regions.count, 3, "izquierda, solape, derecha")
        // La región del solape contiene (7.5, 7.5) y mide 25
        let overlap = RegionFinder.region(at: Vec2(7.5, 7.5), in: regions)
        XCTAssertEqual(overlap?.area ?? 0, 25, accuracy: 1e-6)
    }

    /// Línea que CRUZA un círculo → dos medias lunas.
    func testLineThroughCircleMakesTwoRegions() {
        var m = SketchModel()
        m.addCircle(center: Vec2(0, 0), radius: 5)
        m.addLine(from: Vec2(-6, 0), to: Vec2(6, 0))
        let regions = RegionFinder.regions(in: m, maxDeviation: 1e-3)
        XCTAssertEqual(regions.count, 2, "el diámetro parte el disco en dos")
        let total = regions.reduce(0.0) { $0 + $1.area }
        XCTAssertEqual(total, .pi * 25, accuracy: 0.3)
    }

    func testSmallestContainingRegionWins() {
        var m = SketchModel()
        // Cuadrado grande con círculo adentro (sin tocarse)
        m.addLine(from: Vec2(0, 0), to: Vec2(20, 0))
        m.addLine(from: Vec2(20, 0), to: Vec2(20, 20))
        m.addLine(from: Vec2(20, 20), to: Vec2(0, 20))
        m.addLine(from: Vec2(0, 20), to: Vec2(0, 0))
        m.addCircle(center: Vec2(10, 10), radius: 3)
        let regions = RegionFinder.regions(in: m)
        let hit = RegionFinder.region(at: Vec2(10, 10), in: regions)
        XCTAssertEqual(hit?.area ?? 0, .pi * 9, accuracy: 0.2,
                       "tocar dentro del círculo elige el círculo, no el cuadrado")
    }
}

final class HitTestTests: XCTestCase {
    let tester = HitTester()

    func makeSquare() -> SketchModel {
        var m = SketchModel()
        m.addLine(from: Vec2(0, 0), to: Vec2(10, 0))
        m.addLine(from: Vec2(10, 0), to: Vec2(10, 10))
        m.addLine(from: Vec2(10, 10), to: Vec2(0, 10))
        m.addLine(from: Vec2(0, 10), to: Vec2(0, 0))
        return m
    }

    func testTapNearCornerSelectsPoint() {
        let m = makeSquare()
        let hit = tester.hitTest(at: Vec2(9.8, 0.15), in: m,
                                 pointRadius: 0.5, curveRadius: 0.3)
        guard case .point(_, let pos) = hit else { return XCTFail("esperaba punto, fue \(hit)") }
        XCTAssertEqual(pos.distance(to: Vec2(10, 0)), 0, accuracy: 1e-9)
    }

    func testTapOnEdgeSelectsCurve() {
        let m = makeSquare()
        let hit = tester.hitTest(at: Vec2(5, 0.2), in: m,
                                 pointRadius: 0.5, curveRadius: 0.4)
        guard case .curve(_, let closest) = hit else { return XCTFail("esperaba curva, fue \(hit)") }
        XCTAssertEqual(closest.distance(to: Vec2(5, 0)), 0, accuracy: 1e-9)
    }

    func testTapInsideSelectsRegion() {
        let m = makeSquare()
        let regions = RegionFinder.regions(in: m)
        let hit = tester.hitTest(at: Vec2(5, 5), in: m,
                                 pointRadius: 0.5, curveRadius: 0.4,
                                 regions: regions)
        guard case .region(let region) = hit else { return XCTFail("esperaba región, fue \(hit)") }
        XCTAssertEqual(region.area, 100, accuracy: 1e-6)
    }

    func testTapInEmptinessIsNone() {
        let m = makeSquare()
        let hit = tester.hitTest(at: Vec2(50, 50), in: m,
                                 pointRadius: 0.5, curveRadius: 0.4,
                                 regions: RegionFinder.regions(in: m))
        XCTAssertTrue(hit.isNone)
    }

    func testDoubleTapChainSelectsWholeSquare() throws {
        let m = makeSquare()
        let first = try XCTUnwrap(m.orderedCurves.first?.id)
        let chain = tester.connectedChain(from: first, in: m)
        XCTAssertEqual(chain.count, 4, "el perfil completo del cuadrado")
    }
}

final class SplineTests: XCTestCase {

    func testThroughPointsSplinePassesThroughAllPoints() {
        let pts = [Vec2(0, 0), Vec2(5, 8), Vec2(10, -2), Vec2(15, 4)]
        let samples = SplineEvaluator.sample(points: pts, mode: .throughPoints, perSegment: 32)
        for p in pts {
            let minDist = samples.map { $0.distance(to: p) }.min() ?? .infinity
            XCTAssertLessThan(minDist, 0.15, "la interpolada pasa por \(p)")
        }
    }

    func testControlPointsSplineClampedToEnds() {
        let ctrl = [Vec2(0, 0), Vec2(5, 10), Vec2(10, 10), Vec2(15, 0)]
        let samples = SplineEvaluator.sample(points: ctrl, mode: .controlPoints, perSegment: 16)
        XCTAssertEqual(samples.first?.distance(to: ctrl.first!) ?? 1, 0, accuracy: 1e-9)
        XCTAssertEqual(samples.last?.distance(to: ctrl.last!) ?? 1, 0, accuracy: 1e-9)
        // NO pasa por los puntos interiores (los atrae, no los toca)
        let d1 = samples.map { $0.distance(to: ctrl[1]) }.min() ?? 0
        XCTAssertGreaterThan(d1, 0.5, "el control interior atrae sin tocar")
    }

    func testSplineCurveInModelIsHittable() {
        var m = SketchModel()
        m.addSpline(through: [Vec2(0, 0), Vec2(5, 8), Vec2(10, 0)], mode: .throughPoints)
        let tester = HitTester()
        // Cerca del vértice de la curva (5, ~8): el punto de paso es topológico
        let hit = tester.hitTest(at: Vec2(5, 8.1), in: m, pointRadius: 0.5, curveRadius: 0.3)
        guard case .point = hit else { return XCTFail("el punto de paso es seleccionable") }
    }
}
