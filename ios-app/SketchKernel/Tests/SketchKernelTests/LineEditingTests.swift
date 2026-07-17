import XCTest
@testable import SketchKernel

/// Entrada numérica al dibujar: longitud/ángulo de la curva caliente mueven el
/// endpoint (el inicio queda fijo) y la topología conectada lo sigue.
final class LineEditingTests: XCTestCase {

    func testSetLengthMovesEndpoint() throws {
        var m = SketchModel(mergeTolerance: 1e-4)
        let l = m.addLine(from: Vec2(0, 0), to: Vec2(3, 0))
        m.setLineLength(l, 5)
        let metrics = try XCTUnwrap(m.lineMetrics(l))
        XCTAssertEqual(try XCTUnwrap(m.position(of: metrics.end)).distance(to: Vec2(5, 0)),
                       0, accuracy: 1e-9, "el end se movió a (5,0)")
        XCTAssertEqual(try XCTUnwrap(m.position(of: metrics.start)).distance(to: Vec2(0, 0)),
                       0, accuracy: 1e-9, "el inicio quedó fijo")
    }

    /// Fijar longitud 5 mueve el end y las curvas que compartían ese punto lo
    /// siguen (topología conectada).
    func testSetLengthDragsConnectedTopology() throws {
        var m = SketchModel(mergeTolerance: 1e-4)
        let l1 = m.addLine(from: Vec2(0, 0), to: Vec2(3, 0))   // el (3,0) es el end
        let l2 = m.addLine(from: Vec2(3, 0), to: Vec2(3, 4))   // arranca en (3,0)
        m.setLineLength(l1, 5)
        // El (3,0) compartido pasó a (5,0): l2 debe arrancar ahí.
        let g2 = try XCTUnwrap(CurveGeometry.resolve(m.curves[l2]!, in: m))
        XCTAssertEqual(g2.evaluate(0).distance(to: Vec2(5, 0)), 0, accuracy: 1e-9,
                       "la línea conectada siguió el punto compartido")
    }

    /// Fijar ángulo 90° vuelve la línea vertical manteniendo la longitud.
    func testSetAngleRotatesKeepingLength() throws {
        var m = SketchModel(mergeTolerance: 1e-4)
        let l = m.addLine(from: Vec2(0, 0), to: Vec2(3, 0))    // longitud 3, ángulo 0
        m.setLineAngle(l, degrees: 90)
        let metrics = try XCTUnwrap(m.lineMetrics(l))
        XCTAssertEqual(metrics.length, 3, accuracy: 1e-9, "longitud conservada")
        XCTAssertEqual(try XCTUnwrap(m.position(of: metrics.end)).distance(to: Vec2(0, 3)),
                       0, accuracy: 1e-9, "vertical exacta")
    }

    func testLineMetricsReportsLengthAndAngle() throws {
        var m = SketchModel(mergeTolerance: 1e-4)
        let l = m.addLine(from: Vec2(0, 0), to: Vec2(0, 4))    // vertical hacia +Y
        let metrics = try XCTUnwrap(m.lineMetrics(l))
        XCTAssertEqual(metrics.length, 4, accuracy: 1e-9)
        XCTAssertEqual(metrics.angleDegrees, 90, accuracy: 1e-9)
    }

    func testLineMetricsNilForNonLine() {
        var m = SketchModel(mergeTolerance: 1e-4)
        let c = m.addCircle(center: Vec2(0, 0), radius: 2)
        XCTAssertNil(m.lineMetrics(c), "un círculo no tiene métricas de línea")
    }
}
