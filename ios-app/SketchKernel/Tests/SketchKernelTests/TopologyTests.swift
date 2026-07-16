import XCTest
@testable import SketchKernel

final class TopologyTests: XCTestCase {

    func testCornerIsOneSharedPoint() {
        var m = SketchModel(mergeTolerance: 1e-3)
        m.addLine(from: Vec2(0, 0), to: Vec2(10, 0))
        m.addLine(from: Vec2(10, 0), to: Vec2(10, 10))
        // 2 líneas que comparten esquina: 3 puntos, no 4
        XCTAssertEqual(m.positions.count, 3)
    }

    func testCornerMergesWithinTolerance() {
        var m = SketchModel(mergeTolerance: 1e-2)
        m.addLine(from: Vec2(0, 0), to: Vec2(10, 0))
        // El segundo trazo llega CERCA de la esquina (error de pulso < tolerancia)
        m.addLine(from: Vec2(10.005, 0.003), to: Vec2(10, 10))
        XCTAssertEqual(m.positions.count, 3, "la esquina imprecisa debe fusionarse")
    }

    func testMovingSharedPointMovesBothLines() throws {
        var m = SketchModel(mergeTolerance: 1e-3)
        let l1 = m.addLine(from: Vec2(0, 0), to: Vec2(10, 0))
        let l2 = m.addLine(from: Vec2(10, 0), to: Vec2(10, 10))
        let corner = try XCTUnwrap(m.existingPoint(near: Vec2(10, 0), tolerance: 1e-6))

        m.movePoint(corner, to: Vec2(12, 1))

        let g1 = try XCTUnwrap(CurveGeometry.resolve(m.curves[l1]!, in: m))
        let g2 = try XCTUnwrap(CurveGeometry.resolve(m.curves[l2]!, in: m))
        XCTAssertEqual(g1.evaluate(1).distance(to: Vec2(12, 1)), 0, accuracy: 1e-9,
                       "el extremo de la primera línea siguió al punto")
        XCTAssertEqual(g2.evaluate(0).distance(to: Vec2(12, 1)), 0, accuracy: 1e-9,
                       "el arranque de la segunda línea siguió al punto")
    }

    func testRectangleFromFourLinesHasFourPoints() {
        var m = SketchModel(mergeTolerance: 1e-3)
        m.addLine(from: Vec2(0, 0), to: Vec2(10, 0))
        m.addLine(from: Vec2(10, 0), to: Vec2(10, 10))
        m.addLine(from: Vec2(10, 10), to: Vec2(0, 10))
        m.addLine(from: Vec2(0, 10), to: Vec2(0, 0))
        XCTAssertEqual(m.positions.count, 4)
        XCTAssertEqual(m.curves.count, 4)
    }

    func testRemoveCurveCollectsOrphanPoints() {
        var m = SketchModel(mergeTolerance: 1e-3)
        let l1 = m.addLine(from: Vec2(0, 0), to: Vec2(10, 0))
        m.addLine(from: Vec2(10, 0), to: Vec2(10, 10))
        m.removeCurve(l1)
        // (0,0) quedó huérfano y se recoge; la esquina compartida sobrevive
        XCTAssertEqual(m.positions.count, 2)
        XCTAssertEqual(m.curves.count, 1)
    }

    func testArcEndProjectedOntoRadius() throws {
        var m = SketchModel(mergeTolerance: 1e-6)
        // end deliberadamente FUERA del círculo de radio 10
        let arc = m.addArc(center: Vec2(0, 0), start: Vec2(10, 0),
                           end: Vec2(0, 14), ccw: true)
        guard case .arc(_, let e, _, _) = m.curves[arc]!.kind else {
            return XCTFail("no es arco")
        }
        let endPos = try XCTUnwrap(m.position(of: e))
        XCTAssertEqual(endPos.distance(to: .zero), 10, accuracy: 1e-9,
                       "el extremo se proyecta al radio definido por start")
    }

    func testUndoByValueSnapshot() {
        var m = SketchModel(mergeTolerance: 1e-3)
        m.addLine(from: Vec2(0, 0), to: Vec2(10, 0))
        let snapshot = m // tipo valor: undo = restaurar la copia
        m.addCircle(center: Vec2(5, 5), radius: 2)
        XCTAssertEqual(m.curves.count, 2)
        m = snapshot
        XCTAssertEqual(m.curves.count, 1)
    }
}
