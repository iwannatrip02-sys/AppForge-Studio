import XCTest
@testable import SketchKernel

/// Trim: recorta el tramo de una curva entre sus intersecciones más cercanas
/// al punto tocado. La pieza que faltaba del bloque de dibujo.
final class TrimTests: XCTestCase {

    /// Línea horizontal cruzada por dos verticales (x=3, x=7). Tap al centro
    /// (5,0) borra el tramo central → quedan [0,3] y [7,10].
    func testLineCrossedByTwoLinesLeavesTwoSegments() {
        var m = SketchModel(mergeTolerance: 1e-4)
        let target = m.addLine(from: Vec2(0, 0), to: Vec2(10, 0))
        m.addLine(from: Vec2(3, -5), to: Vec2(3, 5))
        m.addLine(from: Vec2(7, -5), to: Vec2(7, 5))

        let ok = m.trim(target, at: Vec2(5, 0))
        XCTAssertTrue(ok)
        XCTAssertNil(m.curves[target], "la curva original desaparece")

        // De las curvas resultantes, las horizontales deben ser [0,3] y [7,10].
        let horizontals = m.orderedCurves.compactMap { c -> (Vec2, Vec2)? in
            guard case .line(let s, let e) = c.kind,
                  let a = m.position(of: s), let b = m.position(of: e),
                  abs(a.y) < 1e-6 && abs(b.y) < 1e-6 else { return nil }
            return (a, b)
        }
        XCTAssertEqual(horizontals.count, 2, "dos segmentos laterales")
        let xs = horizontals.flatMap { [$0.0.x, $0.1.x] }.sorted()
        XCTAssertEqual(xs, [0, 3, 7, 10], "extremos en 0,3 y 7,10")
    }

    /// Los extremos NO tocados conservan su PointID original.
    func testUntouchedEndpointsKeepPointID() throws {
        var m = SketchModel(mergeTolerance: 1e-4)
        let target = m.addLine(from: Vec2(0, 0), to: Vec2(10, 0))
        guard case .line(let startID, let endID) = m.curves[target]!.kind else {
            return XCTFail("no es línea")
        }
        m.addLine(from: Vec2(3, -5), to: Vec2(3, 5))
        m.addLine(from: Vec2(7, -5), to: Vec2(7, 5))

        XCTAssertTrue(m.trim(target, at: Vec2(5, 0)))

        // startID (0,0) y endID (10,0) siguen existiendo y en su posición.
        XCTAssertEqual(try XCTUnwrap(m.position(of: startID)).distance(to: Vec2(0, 0)), 0, accuracy: 1e-9)
        XCTAssertEqual(try XCTUnwrap(m.position(of: endID)).distance(to: Vec2(10, 0)), 0, accuracy: 1e-9)
        // Y una curva resultante debe referenciar cada uno de ellos.
        XCTAssertTrue(m.curvesAttached(to: startID).count >= 1, "el extremo (0,0) sigue en un trazo")
        XCTAssertTrue(m.curvesAttached(to: endID).count >= 1, "el extremo (10,0) sigue en un trazo")
    }

    /// Trim de una línea con UN solo corte: deja el tramo sin `p`.
    func testLineWithSingleCutKeepsFarSegment() {
        var m = SketchModel(mergeTolerance: 1e-4)
        let target = m.addLine(from: Vec2(0, 0), to: Vec2(10, 0))
        m.addLine(from: Vec2(4, -5), to: Vec2(4, 5))   // corta en x=4
        // Tap cerca del origen → borra [0,4], deja [4,10].
        XCTAssertTrue(m.trim(target, at: Vec2(1, 0)))
        let horizontals = m.orderedCurves.compactMap { c -> (Vec2, Vec2)? in
            guard case .line(let s, let e) = c.kind,
                  let a = m.position(of: s), let b = m.position(of: e),
                  abs(a.y) < 1e-6 && abs(b.y) < 1e-6 else { return nil }
            return (a, b)
        }
        XCTAssertEqual(horizontals.count, 1)
        let xs = horizontals.flatMap { [$0.0.x, $0.1.x] }.sorted()
        XCTAssertEqual(xs.count, 2)
        XCTAssertEqual(xs.first ?? -1, 4, accuracy: 1e-6)
        XCTAssertEqual(xs.last ?? -1, 10, accuracy: 1e-6)
    }

    /// Círculo cruzado por una línea (diámetro) → queda un arco.
    func testCircleCrossedByLineBecomesArc() {
        var m = SketchModel(mergeTolerance: 1e-4)
        let circ = m.addCircle(center: Vec2(0, 0), radius: 5)
        m.addLine(from: Vec2(-8, 0), to: Vec2(8, 0))   // diámetro horizontal

        // Tap arriba (0,5) → borra el semicírculo superior, queda el inferior.
        XCTAssertTrue(m.trim(circ, at: Vec2(0, 5)))
        XCTAssertNil(m.curves[circ], "el círculo se convierte")
        let arcs = m.orderedCurves.filter { if case .arc = $0.kind { return true } else { return false } }
        XCTAssertEqual(arcs.count, 1, "queda un arco")
        // El arco resultante pasa por (0,-5) y no por (0,5).
        guard let g = CurveGeometry.resolve(arcs[0], in: m) else { return XCTFail() }
        let below = g.closestPoint(to: Vec2(0, -5)).distance
        let above = g.closestPoint(to: Vec2(0, 5)).distance
        XCTAssertLessThan(below, 1e-3, "el arco conservado pasa por abajo")
        XCTAssertGreaterThan(above, 1.0, "y no por arriba (se recortó)")
    }

    /// Círculo con <2 cortes (una línea tangente = 1 corte) → no-op, false.
    func testCircleWithFewerThanTwoCutsIsNoOp() {
        var m = SketchModel(mergeTolerance: 1e-4)
        let circ = m.addCircle(center: Vec2(0, 0), radius: 5)
        m.addLine(from: Vec2(-8, 5), to: Vec2(8, 5))   // tangente arriba: 1 corte
        XCTAssertFalse(m.trim(circ, at: Vec2(0, 5)), "menos de 2 cortes no recorta")
        XCTAssertNotNil(m.curves[circ], "el círculo sigue entero")
    }

    /// Curva SIN cruces (línea suelta) → trim la borra entera y devuelve true.
    func testTrimOfLooseCurveDeletesIt() {
        var m = SketchModel(mergeTolerance: 1e-4)
        let target = m.addLine(from: Vec2(0, 0), to: Vec2(10, 0))
        XCTAssertTrue(m.trim(target, at: Vec2(5, 0)))
        XCTAssertNil(m.curves[target])
        XCTAssertTrue(m.curves.isEmpty, "no queda nada")
    }

    /// Arco cruzado por una línea → arco(s) recortado(s).
    func testArcTrimmedByLine() {
        var m = SketchModel(mergeTolerance: 1e-4)
        // Semicírculo superior de radio 5 (de (5,0) a (-5,0) por arriba).
        let arc = m.addArc(center: Vec2(0, 0), start: Vec2(5, 0), end: Vec2(-5, 0), ccw: true)
        // Vertical x=0 corta el arco en (0,5).
        m.addLine(from: Vec2(0, -1), to: Vec2(0, 6))
        // Tap en el cuadrante derecho (por ~45°) borra ese tramo.
        let right = Vec2(5, 0).rotated(by: .pi / 4).normalized * 5
        XCTAssertTrue(m.trim(arc, at: right))
        XCTAssertNil(m.curves[arc])
        let arcs = m.orderedCurves.filter { if case .arc = $0.kind { return true } else { return false } }
        XCTAssertEqual(arcs.count, 1, "queda un sub-arco (el otro lado)")
    }

    /// Spline: no soportada en v1 → false, sin cambios.
    func testSplineTrimUnsupported() {
        var m = SketchModel(mergeTolerance: 1e-4)
        let sp = m.addSpline(through: [Vec2(0, 0), Vec2(5, 5), Vec2(10, 0)], mode: .throughPoints)
        m.addLine(from: Vec2(5, -5), to: Vec2(5, 10))
        XCTAssertFalse(m.trim(sp, at: Vec2(5, 5)), "spline no soportada")
        XCTAssertNotNil(m.curves[sp], "sigue intacta")
    }
}
