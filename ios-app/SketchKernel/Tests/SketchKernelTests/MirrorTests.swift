import XCTest
@testable import SketchKernel

/// Contrato del ESPEJO 2D: exacto para todo tipo de curva, y la topología se
/// cose sola sobre el eje.
///
/// Es lo que permite el flujo real de pieza simétrica: dibujas media, reflejas,
/// y el resultado es UN perfil cerrado extruible — no dos mitades sueltas.
final class MirrorTests: XCTestCase {

    // MARK: - Exactitud por tipo de curva

    func testLineMirrorsAcrossVerticalAxis() throws {
        var m = SketchModel(mergeTolerance: 1e-9)
        let id = m.addLine(from: Vec2(1, 0), to: Vec2(3, 2))
        let made = m.mirrorCurves([id], axisPoint: Vec2(0, 0), axisDirection: Vec2(0, 1))
        XCTAssertEqual(made.count, 1)

        guard case .line(let s, let e)? = m.curves[try XCTUnwrap(made.first)]?.kind else {
            return XCTFail("una recta refleja a recta")
        }
        let sp = try XCTUnwrap(m.position(of: s))
        let ep = try XCTUnwrap(m.position(of: e))
        XCTAssertEqual(sp.x, -1, accuracy: 1e-9)
        XCTAssertEqual(sp.y, 0, accuracy: 1e-9)
        XCTAssertEqual(ep.x, -3, accuracy: 1e-9)
        XCTAssertEqual(ep.y, 2, accuracy: 1e-9)
    }

    func testCircleKeepsRadiusAndMirrorsCenter() throws {
        var m = SketchModel(mergeTolerance: 1e-9)
        let id = m.addCircle(center: Vec2(4, 1), radius: 2.5)
        let made = m.mirrorCurves([id], axisPoint: .zero, axisDirection: Vec2(0, 1))

        guard case .circle(let c, let r)? = m.curves[try XCTUnwrap(made.first)]?.kind else {
            return XCTFail("un círculo refleja a círculo")
        }
        XCTAssertEqual(r, 2.5, accuracy: 1e-12, "el radio no cambia al reflejar")
        let cp = try XCTUnwrap(m.position(of: c))
        XCTAssertEqual(cp.x, -4, accuracy: 1e-9)
        XCTAssertEqual(cp.y, 1, accuracy: 1e-9)
    }

    /// Una reflexión invierte la orientación del plano: el arco espejo debe
    /// recorrerse al revés. Sin esto el arco sale abombado por el lado contrario.
    func testArcFlipsSweepDirection() throws {
        var m = SketchModel(mergeTolerance: 1e-9)
        let id = m.addArc(center: Vec2(3, 0), start: Vec2(5, 0), end: Vec2(3, 2), ccw: true)
        let made = m.mirrorCurves([id], axisPoint: .zero, axisDirection: Vec2(0, 1))

        guard case .arc(_, _, let c, let ccw)? = m.curves[try XCTUnwrap(made.first)]?.kind else {
            return XCTFail("un arco refleja a arco")
        }
        XCTAssertFalse(ccw, "el sentido del barrido se invierte al reflejar")
        let cp = try XCTUnwrap(m.position(of: c))
        XCTAssertEqual(cp.x, -3, accuracy: 1e-9)
    }

    func testSplineMirrorsAllItsPoints() throws {
        var m = SketchModel(mergeTolerance: 1e-9)
        let id = m.addSpline(through: [Vec2(1, 0), Vec2(2, 1), Vec2(3, 0)],
                             mode: .throughPoints)
        let made = m.mirrorCurves([id], axisPoint: .zero, axisDirection: Vec2(0, 1))

        guard case .spline(let pts, let mode)? = m.curves[try XCTUnwrap(made.first)]?.kind else {
            return XCTFail("una spline refleja a spline")
        }
        XCTAssertEqual(mode, .throughPoints, "el modo de spline se conserva")
        XCTAssertEqual(pts.count, 3)
        let xs = try pts.map { try XCTUnwrap(m.position(of: $0)).x }
        XCTAssertEqual(xs, [-1, -2, -3])
    }

    // MARK: - La topología se cose sola

    /// El caso que da valor: media pieza + espejo = UN perfil cerrado. Los
    /// puntos que caen sobre el eje se funden con sus originales.
    func testMirroringHalfProfileClosesASingleRegion() throws {
        var m = SketchModel(mergeTolerance: 1e-6)
        // Media "U" a la derecha del eje X=0, tocando el eje en (0,0) y (0,4).
        m.addLine(from: Vec2(0, 0), to: Vec2(3, 0))
        m.addLine(from: Vec2(3, 0), to: Vec2(3, 4))
        m.addLine(from: Vec2(3, 4), to: Vec2(0, 4))

        XCTAssertTrue(RegionFinder.regions(in: m).isEmpty,
                      "media pieza sola no encierra área")

        m.mirrorAll(axisPoint: .zero, axisDirection: Vec2(0, 1))

        let regions = RegionFinder.regions(in: m)
        XCTAssertEqual(regions.count, 1,
                       "la pieza reflejada cierra UNA región extruible")
        XCTAssertEqual(try XCTUnwrap(regions.first).area, 6 * 4, accuracy: 1e-6,
                       "rectángulo completo 6×4 = 24")
    }

    /// Los puntos sobre el eje NO se duplican: se funden por topología.
    func testPointsOnAxisAreWeldedNotDuplicated() {
        var m = SketchModel(mergeTolerance: 1e-6)
        m.addLine(from: Vec2(0, 0), to: Vec2(2, 0))
        let before = m.positions.count           // 2 puntos
        m.mirrorAll(axisPoint: .zero, axisDirection: Vec2(0, 1))
        // El espejo aporta UN punto nuevo (−2,0); el (0,0) se funde.
        XCTAssertEqual(m.positions.count, before + 1,
                       "el punto sobre el eje se comparte, no se duplica")
    }

    /// Un segmento que YACE sobre el eje se refleja sobre sí mismo: duplicarlo
    /// pondría dos aristas encima y el grafo planar vería un tramo doble.
    func testSegmentLyingOnAxisIsNotDuplicated() {
        var m = SketchModel(mergeTolerance: 1e-6)
        let id = m.addLine(from: Vec2(0, 0), to: Vec2(0, 5))   // sobre el eje X=0
        let made = m.mirrorCurves([id], axisPoint: .zero, axisDirection: Vec2(0, 1))
        XCTAssertTrue(made.isEmpty,
                      "reflejar un segmento contenido en el eje no crea una copia encima")
        XCTAssertEqual(m.orderedCurves.count, 1, "la geometría no se duplica")
    }

    /// Ídem para un círculo centrado en el eje: ya es simétrico.
    func testCircleCenteredOnAxisIsNotDuplicated() {
        var m = SketchModel(mergeTolerance: 1e-6)
        let id = m.addCircle(center: Vec2(0, 3), radius: 1)   // centro sobre X=0
        let made = m.mirrorCurves([id], axisPoint: .zero, axisDirection: Vec2(0, 1))
        XCTAssertTrue(made.isEmpty, "un círculo centrado en el eje se mapea a sí mismo")
        XCTAssertEqual(m.orderedCurves.count, 1)
    }

    // MARK: - Bordes

    func testDegenerateAxisIsRejected() {
        var m = SketchModel(mergeTolerance: 1e-6)
        let id = m.addLine(from: Vec2(1, 1), to: Vec2(2, 2))
        XCTAssertTrue(m.mirrorCurves([id], axisPoint: .zero, axisDirection: .zero).isEmpty,
                      "un eje sin dirección no define reflexión")
    }

    func testUnknownCurvesAreIgnored() {
        var m = SketchModel(mergeTolerance: 1e-6)
        XCTAssertTrue(m.mirrorCurves([CurveID()], axisPoint: .zero,
                                     axisDirection: Vec2(1, 0)).isEmpty)
    }

    /// `mirrorAll` ignora la geometría de construcción: es un helper de trazado,
    /// no parte de la pieza.
    func testMirrorAllSkipsConstructionGeometry() {
        var m = SketchModel(mergeTolerance: 1e-6)
        let real = m.addLine(from: Vec2(1, 0), to: Vec2(2, 0))
        let helper = m.addLine(from: Vec2(1, 3), to: Vec2(2, 3))
        m.setConstruction(helper, true)

        let made = m.mirrorAll(axisPoint: .zero, axisDirection: Vec2(0, 1))
        XCTAssertEqual(made.count, 1, "solo se refleja la geometría real")
        _ = real
    }
}
