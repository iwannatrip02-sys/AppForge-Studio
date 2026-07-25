import XCTest
@testable import SketchKernel

/// Contrato del REDONDEO DE ESQUINA 2D — la operación más usada del dibujo
/// mecánico, que no existía.
///
/// Cobra sentido pleno junto a los perfiles analíticos: el arco que se inserta
/// aquí sobrevive hasta el B-rep como cara cilíndrica REAL, en vez de volver a
/// discretizarse en ~25 segmentos planos.
final class FilletCornerTests: XCTestCase {

    /// Esquina recta en el origen: (10,0) ← (0,0) → (0,10).
    private func rightAngleCorner() -> (model: SketchModel, corner: PointID) {
        var m = SketchModel(mergeTolerance: 1e-6)
        m.addLine(from: Vec2(0, 0), to: Vec2(10, 0))
        m.addLine(from: Vec2(0, 0), to: Vec2(0, 10))
        guard let corner = m.existingPoint(near: Vec2(0, 0), tolerance: 1e-9) else {
            preconditionFailure("las dos líneas comparten el punto (0,0) por topología")
        }
        return (m, corner)
    }

    // MARK: - Geometría del caso recto

    /// En una esquina de 90°, `t = r / tan(45°) = r`: las tangencias caen a
    /// exactamente `r` de la esquina, y el centro en la diagonal a `r√2`.
    func testRightAngleFilletHasExactTangencyAndCenter() throws {
        var (m, corner) = rightAngleCorner()
        let arcID = try XCTUnwrap(m.filletCorner(at: corner, radius: 2),
                                  "una esquina recta de lados 10 debe poder redondearse con r=2")

        let curve = try XCTUnwrap(m.curves[arcID])
        guard case .arc(let s, let e, let c, _) = curve.kind else {
            return XCTFail("el redondeo debe insertar un ARCO")
        }
        let sp = try XCTUnwrap(m.position(of: s))
        let ep = try XCTUnwrap(m.position(of: e))
        let cp = try XCTUnwrap(m.position(of: c))

        // Tangencias a distancia r sobre cada eje.
        let onX = [sp, ep].first { abs($0.y) < 1e-9 }
        let onY = [sp, ep].first { abs($0.x) < 1e-9 }
        XCTAssertEqual(try XCTUnwrap(onX).x, 2, accuracy: 1e-9)
        XCTAssertEqual(try XCTUnwrap(onY).y, 2, accuracy: 1e-9)

        // Centro en la bisectriz, equidistante r de ambas tangencias.
        XCTAssertEqual(cp.x, 2, accuracy: 1e-9)
        XCTAssertEqual(cp.y, 2, accuracy: 1e-9)
        XCTAssertEqual(cp.distance(to: sp), 2, accuracy: 1e-9)
        XCTAssertEqual(cp.distance(to: ep), 2, accuracy: 1e-9)
    }

    /// Las dos líneas quedan RECORTADAS hasta la tangencia: la esquina viva
    /// desaparece y ninguna curva sigue pasando por el origen.
    func testLinesAreTrimmedBackToTangency() throws {
        var (m, corner) = rightAngleCorner()
        _ = try XCTUnwrap(m.filletCorner(at: corner, radius: 3))

        XCTAssertNil(m.position(of: corner),
                     "la esquina compartida deja de existir tras el redondeo")
        for curve in m.orderedCurves {
            guard case .line = curve.kind,
                  let g = CurveGeometry.resolve(curve, in: m) else { continue }
            XCTAssertGreaterThan(g.closestPoint(to: Vec2(0, 0)).distance, 2.9,
                                 "ninguna línea debe seguir llegando a la esquina")
        }
    }

    /// El perfil sigue cerrando región: redondear no rompe la topología.
    func testFilletedSquareStillFormsOneRegion() throws {
        var m = SketchModel(mergeTolerance: 1e-6)
        m.addLine(from: Vec2(0, 0), to: Vec2(10, 0))
        m.addLine(from: Vec2(10, 0), to: Vec2(10, 10))
        m.addLine(from: Vec2(10, 10), to: Vec2(0, 10))
        m.addLine(from: Vec2(0, 10), to: Vec2(0, 0))

        let corner = try XCTUnwrap(m.existingPoint(near: Vec2(0, 0), tolerance: 1e-9))
        _ = try XCTUnwrap(m.filletCorner(at: corner, radius: 2))

        let regions = RegionFinder.regions(in: m, maxDeviation: 1e-3)
        XCTAssertEqual(regions.count, 1, "el cuadrado redondeado sigue siendo UNA región")
        // Área = 100 − (esquina recortada 2×2) + (cuarto de disco r=2).
        let expected = 100 - 4 + .pi * 4 / 4
        XCTAssertEqual(try XCTUnwrap(regions.first).area, expected, accuracy: 0.05)
    }

    /// Y el contorno conserva la identidad del arco (procedencia): es lo que
    /// hace que la extrusión produzca una cara cilíndrica real.
    func testFilletedCornerSurvivesAsAnalyticArcInBoundary() throws {
        var m = SketchModel(mergeTolerance: 1e-6)
        m.addLine(from: Vec2(0, 0), to: Vec2(10, 0))
        m.addLine(from: Vec2(10, 0), to: Vec2(10, 10))
        m.addLine(from: Vec2(10, 10), to: Vec2(0, 10))
        m.addLine(from: Vec2(0, 10), to: Vec2(0, 0))
        let corner = try XCTUnwrap(m.existingPoint(near: Vec2(0, 0), tolerance: 1e-9))
        let arcID = try XCTUnwrap(m.filletCorner(at: corner, radius: 2))

        let region = try XCTUnwrap(RegionFinder.regions(in: m, maxDeviation: 1e-3).first)
        XCTAssertEqual(region.boundary.count, 5,
                       "los 4 lados (dos de ellos acortados) + el arco = 5 tramos")
        XCTAssertTrue(region.boundary.contains { $0.curveID == arcID },
                      "el arco del redondeo viaja al contorno como curva analítica")
    }

    // MARK: - Rechazos honestos

    func testRejectsRadiusThatWouldEatTheSegments() {
        var (m, corner) = rightAngleCorner()
        // t = r para 90°; los lados miden 10 → r=20 es imposible.
        XCTAssertNil(m.filletCorner(at: corner, radius: 20),
                     "un radio que se come el segmento debe rechazarse, no deformar")
    }

    func testRejectsCollinearLines() throws {
        var m = SketchModel(mergeTolerance: 1e-6)
        m.addLine(from: Vec2(0, 0), to: Vec2(10, 0))
        m.addLine(from: Vec2(0, 0), to: Vec2(-10, 0))
        let corner = try XCTUnwrap(m.existingPoint(near: Vec2(0, 0), tolerance: 1e-9))
        XCTAssertNil(m.filletCorner(at: corner, radius: 1),
                     "dos líneas colineales no forman esquina: el radio sería infinito")
    }

    func testRejectsCornerWithoutExactlyTwoLines() throws {
        var m = SketchModel(mergeTolerance: 1e-6)
        m.addLine(from: Vec2(0, 0), to: Vec2(10, 0))
        let corner = try XCTUnwrap(m.existingPoint(near: Vec2(0, 0), tolerance: 1e-9))
        XCTAssertNil(m.filletCorner(at: corner, radius: 1),
                     "una sola línea no tiene esquina")

        m.addLine(from: Vec2(0, 0), to: Vec2(0, 10))
        m.addLine(from: Vec2(0, 0), to: Vec2(-5, -5))
        XCTAssertNil(m.filletCorner(at: corner, radius: 1),
                     "con tres líneas la esquina es ambigua: no se adivina")
    }

    func testRejectsNonPositiveRadius() throws {
        var (m, corner) = rightAngleCorner()
        XCTAssertNil(m.filletCorner(at: corner, radius: 0))
        XCTAssertNil(m.filletCorner(at: corner, radius: -3))
    }
}
