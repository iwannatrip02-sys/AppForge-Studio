import XCTest
@testable import SketchKernel

final class SnapTests: XCTestCase {
    let engine = SnapEngine()

    func testEndpointBeatsGrid() {
        var m = SketchModel()
        m.addLine(from: Vec2(0, 0), to: Vec2(10, 0))
        let ctx = SnapContext(cursor: Vec2(9.9, 0.1), radius: 0.5, gridSpacing: 1.0)
        let r = engine.snap(ctx, in: m)
        XCTAssertEqual(r.kind, .endpoint)
        XCTAssertEqual(r.position.distance(to: Vec2(10, 0)), 0, accuracy: 1e-9)
        XCTAssertNotNil(r.pointID, "trae el PointID para fusionar topología al confirmar")
    }

    func testMidpointOfLine() {
        var m = SketchModel()
        m.addLine(from: Vec2(0, 0), to: Vec2(10, 0))
        let r = engine.snap(SnapContext(cursor: Vec2(5.2, 0.2), radius: 0.5), in: m)
        XCTAssertEqual(r.kind, .midpoint)
        XCTAssertEqual(r.position.distance(to: Vec2(5, 0)), 0, accuracy: 1e-9)
    }

    /// EL caso de aceptación del contrato: el centro de un círculo/cara es
    /// encontrable de inmediato (hueco centrado en el cubo al primer intento).
    func testCircleCenterSnap() {
        var m = SketchModel()
        m.addCircle(center: Vec2(5, 5), radius: 3)
        let r = engine.snap(SnapContext(cursor: Vec2(5.3, 4.8), radius: 0.6), in: m)
        // El centro del círculo ES un punto topológico → endpoint (prioridad máxima)
        XCTAssertTrue(r.kind == .endpoint || r.kind == .center)
        XCTAssertEqual(r.position.distance(to: Vec2(5, 5)), 0, accuracy: 1e-9)
    }

    /// El centro de una CARA cuadrada (contorno de 4 líneas): cruce de las
    /// alineaciones con los puntos medios de los lados.
    func testSquareCenterViaMidpointAlignments() {
        var m = SketchModel()
        m.addLine(from: Vec2(0, 0), to: Vec2(10, 0))
        m.addLine(from: Vec2(10, 0), to: Vec2(10, 10))
        m.addLine(from: Vec2(10, 10), to: Vec2(0, 10))
        m.addLine(from: Vec2(0, 10), to: Vec2(0, 0))
        // Cursor cerca del centro (5,5): no hay punto duro ahí, pero los medios
        // de los lados están en x=5 y y=5 → cruce de guías de alineación
        let r = engine.snap(SnapContext(cursor: Vec2(5.2, 5.3), radius: 0.5), in: m)
        XCTAssertEqual(r.kind, .guideIntersection)
        XCTAssertEqual(r.position.distance(to: Vec2(5, 5)), 0, accuracy: 1e-6,
                       "el centro del cuadrado se engancha por guías de los medios")
        XCTAssertEqual(r.guides.count, 2, "dos punteadas visibles")
    }

    func testIntersectionOfCrossingLines() {
        var m = SketchModel()
        m.addLine(from: Vec2(0, 0), to: Vec2(10, 10))
        m.addLine(from: Vec2(0, 10), to: Vec2(10, 0))
        let r = engine.snap(SnapContext(cursor: Vec2(5.2, 5.1), radius: 0.5), in: m)
        XCTAssertEqual(r.kind, .intersection)
        XCTAssertEqual(r.position.distance(to: Vec2(5, 5)), 0, accuracy: 1e-9)
    }

    func testHorizontalGuideFromReference() {
        let m = SketchModel() // lienzo vacío: solo la referencia del trazo en curso
        let ctx = SnapContext(cursor: Vec2(8, 0.2), radius: 0.4,
                              referencePoint: Vec2(0, 0))
        let r = engine.snap(ctx, in: m)
        XCTAssertEqual(r.kind, .guide)
        XCTAssertEqual(r.position.y, 0, accuracy: 1e-9, "encajado a la horizontal")
        XCTAssertEqual(r.position.x, 8, accuracy: 1e-9, "x libre")
        XCTAssertEqual(r.guides.first?.kind, .horizontal)
    }

    func testQuadrantSnap() {
        var m = SketchModel()
        m.addCircle(center: Vec2(0, 0), radius: 5)
        let r = engine.snap(SnapContext(cursor: Vec2(5.2, 0.2), radius: 0.5), in: m)
        XCTAssertEqual(r.kind, .quadrant)
        XCTAssertEqual(r.position.distance(to: Vec2(5, 0)), 0, accuracy: 1e-9)
    }

    func testOnCurveSnap() {
        var m = SketchModel()
        m.addLine(from: Vec2(0, 0), to: Vec2(10, 0))
        // Lejos de extremos y medio, cerca del trazo
        let r = engine.snap(SnapContext(cursor: Vec2(7.3, 0.2), radius: 0.3), in: m)
        XCTAssertEqual(r.kind, .onCurve)
        XCTAssertEqual(r.position.y, 0, accuracy: 1e-9)
    }

    func testGridWhenNothingElse() {
        let m = SketchModel()
        let r = engine.snap(SnapContext(cursor: Vec2(3.1, 6.9), radius: 0.3,
                                        gridSpacing: 1.0), in: m)
        XCTAssertEqual(r.kind, .grid)
        XCTAssertEqual(r.position.distance(to: Vec2(3, 7)), 0, accuracy: 1e-9)
    }

    func testNoSnapReturnsFreePosition() {
        let m = SketchModel()
        let cursor = Vec2(3.14, 2.71)
        let r = engine.snap(SnapContext(cursor: cursor, radius: 0.3), in: m)
        XCTAssertEqual(r.kind, SnapKind.none)
        XCTAssertEqual(r.position.distance(to: cursor), 0, accuracy: 1e-12)
    }

    func testExcludedPointIsIgnoredWhileDragging() throws {
        var m = SketchModel()
        m.addLine(from: Vec2(0, 0), to: Vec2(10, 0))
        let dragged = try XCTUnwrap(m.existingPoint(near: Vec2(10, 0), tolerance: 1e-6))
        // Arrastrando el propio punto: no debe engancharse a sí mismo
        let ctx = SnapContext(cursor: Vec2(10.05, 0.05), radius: 0.5,
                              excludedPoints: [dragged])
        let r = engine.snap(ctx, in: m)
        XCTAssertNotEqual(r.pointID, dragged)
    }
}
