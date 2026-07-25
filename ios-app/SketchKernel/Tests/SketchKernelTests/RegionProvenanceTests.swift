import XCTest
@testable import SketchKernel

/// Contrato de PROCEDENCIA del contorno de una región.
///
/// Por qué existe: `RegionFinder` discretiza todas las curvas para armar el
/// grafo planar, así que el contorno sale como polígono. Cuando ese polígono
/// alimentaba directamente la extrusión, un círculo dibujado producía un PRISMA
/// de ~50 caras planas en vez de un cilindro — de ahí el "el cilindro no se ve
/// redondo" y "los objetos se separan por polígonos" del feedback de device.
///
/// `SketchRegion.boundary` conserva qué curva es cada tramo y qué intervalo de
/// su parámetro cubre, para que el perfil B-rep se reconstruya con la curva
/// ANALÍTICA original. Estos tests fijan ese invariante.
final class RegionProvenanceTests: XCTestCase {

    // MARK: - Un círculo sigue siendo UN círculo

    func testCircleRegionKeepsOneCurveEdge() {
        var m = SketchModel()
        let id = m.addCircle(center: Vec2(0, 0), radius: 5)

        guard let region = RegionFinder.regions(in: m, maxDeviation: 1e-3).first else {
            return XCTFail("el círculo debe formar una región")
        }

        // Los ~50 micro-tramos de la discretización se funden en UN solo tramo.
        XCTAssertEqual(region.boundary.count, 1,
            "un círculo debe quedar como UN tramo de curva, no como sus segmentos")
        XCTAssertEqual(region.boundary.first?.curveID, id,
            "el tramo debe apuntar a la curva círculo original")
        XCTAssertEqual(region.boundary.first?.sweep ?? 0, 1, accuracy: 1e-9,
            "el tramo debe cubrir el círculo entero (t 0→1)")
    }

    /// El polígono sigue existiendo (hit-testing y sombreado lo usan): la
    /// procedencia se AÑADE, no reemplaza.
    func testCircleRegionStillHasPolygon() {
        var m = SketchModel()
        m.addCircle(center: Vec2(0, 0), radius: 5)
        guard let region = RegionFinder.regions(in: m, maxDeviation: 1e-3).first else {
            return XCTFail("el círculo debe formar una región")
        }
        XCTAssertGreaterThan(region.polygon.count, 20, "el polígono se conserva")
        XCTAssertTrue(region.contains(Vec2(1, 1)))
    }

    // MARK: - Perfiles de líneas

    func testSquareRegionHasFourLineEdges() {
        var m = SketchModel()
        let ids = [
            m.addLine(from: Vec2(0, 0), to: Vec2(10, 0)),
            m.addLine(from: Vec2(10, 0), to: Vec2(10, 10)),
            m.addLine(from: Vec2(10, 10), to: Vec2(0, 10)),
            m.addLine(from: Vec2(0, 10), to: Vec2(0, 0)),
        ]
        guard let region = RegionFinder.regions(in: m).first else {
            return XCTFail("el cuadrado debe formar una región")
        }

        XCTAssertEqual(region.boundary.count, 4, "cuatro lados = cuatro tramos")
        XCTAssertEqual(Set(region.boundary.map { $0.curveID }), Set(ids),
            "los tramos deben referirse a las cuatro líneas dibujadas")
        for edge in region.boundary {
            XCTAssertEqual(edge.sweep, 1, accuracy: 1e-9,
                "cada lado se recorre entero")
        }
    }

    // MARK: - Perfil mixto (el caso que rompía todo)

    /// Tres lados rectos + un semicírculo. El arco NO debe degradarse a los ~25
    /// segmentos de su discretización: debe salir como UN tramo de arco.
    func testMixedProfileKeepsArcAsSingleEdge() {
        var m = SketchModel()
        let bottom = m.addLine(from: Vec2(0, 0), to: Vec2(10, 0))
        let right = m.addLine(from: Vec2(10, 0), to: Vec2(10, 10))
        let top = m.addLine(from: Vec2(10, 10), to: Vec2(0, 10))
        // Semicírculo que cierra por la izquierda, de (0,10) a (0,0).
        let arc = m.addArc(center: Vec2(0, 5), start: Vec2(0, 10), end: Vec2(0, 0), ccw: true)

        guard let region = RegionFinder.regions(in: m, maxDeviation: 1e-3).first else {
            return XCTFail("el perfil mixto debe formar una región")
        }

        XCTAssertEqual(region.boundary.count, 4,
            "tres líneas + un arco = cuatro tramos (el arco NO se fragmenta)")
        XCTAssertEqual(Set(region.boundary.map { $0.curveID }),
                       Set([bottom, right, top, arc]))

        guard let arcEdge = region.boundary.first(where: { $0.curveID == arc }) else {
            return XCTFail("el arco debe estar en el contorno")
        }
        XCTAssertEqual(arcEdge.sweep, 1, accuracy: 1e-9,
            "el arco se recorre entero como una sola curva")

        // Área = cuadrado 10×10 + medio disco de radio 5.
        XCTAssertEqual(region.area, 100 + .pi * 25 / 2, accuracy: 0.2)
    }

    // MARK: - Fusión de tramos

    /// `mergeRuns` funde tramos contiguos de la misma curva y respeta el corte
    /// cuando cambia de curva.
    func testMergeRunsFusesContiguousStepsOfSameCurve() {
        let a = CurveID(), b = CurveID()
        let steps = [
            RegionEdge(curveID: a, tStart: 0.0, tEnd: 0.25),
            RegionEdge(curveID: a, tStart: 0.25, tEnd: 0.5),
            RegionEdge(curveID: a, tStart: 0.5, tEnd: 1.0),
            RegionEdge(curveID: b, tStart: 0.0, tEnd: 0.5),
            RegionEdge(curveID: b, tStart: 0.5, tEnd: 1.0),
        ]
        let merged = RegionFinder.mergeRuns(steps)
        XCTAssertEqual(merged.count, 2, "dos curvas = dos tramos")
        XCTAssertEqual(merged[0].curveID, a)
        XCTAssertEqual(merged[0].tStart, 0.0, accuracy: 1e-12)
        XCTAssertEqual(merged[0].tEnd, 1.0, accuracy: 1e-12)
        XCTAssertEqual(merged[1].curveID, b)
        XCTAssertEqual(merged[1].tEnd, 1.0, accuracy: 1e-12)
    }

    /// Un recorrido que arranca a mitad de un círculo cerrado se emite como la
    /// curva completa, no como dos trozos partidos por el punto de arranque.
    func testMergeRunsClosedCurveStartingMidRing() {
        let c = CurveID()
        let steps = [
            RegionEdge(curveID: c, tStart: 0.5, tEnd: 0.75),
            RegionEdge(curveID: c, tStart: 0.75, tEnd: 1.0),
            RegionEdge(curveID: c, tStart: 0.0, tEnd: 0.25),
            RegionEdge(curveID: c, tStart: 0.25, tEnd: 0.5),
        ]
        let merged = RegionFinder.mergeRuns(steps)
        XCTAssertEqual(merged.count, 1, "una sola curva cerrada = un tramo")
        XCTAssertEqual(merged[0].tStart, 0.0, accuracy: 1e-12)
        XCTAssertEqual(merged[0].tEnd, 1.0, accuracy: 1e-12)
    }

    /// Recorrido en sentido inverso: el tramo sale invertido (t 1→0).
    func testMergeRunsClosedCurveReversed() {
        let c = CurveID()
        let steps = [
            RegionEdge(curveID: c, tStart: 1.0, tEnd: 0.75),
            RegionEdge(curveID: c, tStart: 0.75, tEnd: 0.5),
            RegionEdge(curveID: c, tStart: 0.5, tEnd: 0.25),
            RegionEdge(curveID: c, tStart: 0.25, tEnd: 0.0),
        ]
        let merged = RegionFinder.mergeRuns(steps)
        XCTAssertEqual(merged.count, 1)
        XCTAssertTrue(merged[0].isReversed, "el sentido del recorrido se conserva")
    }

    // MARK: - discretizeWithParams coincide con evaluate

    /// El parámetro que viaja con cada punto debe reproducir ese mismo punto al
    /// evaluar la curva — es el supuesto sobre el que se reconstruye el perfil.
    func testDiscretizeParamsAgreeWithEvaluate() {
        var m = SketchModel()
        let id = m.addCircle(center: Vec2(2, -1), radius: 3)
        guard let curve = m.curves[id],
              let g = CurveGeometry.resolve(curve, in: m) else {
            return XCTFail("la curva debe resolver")
        }
        for (point, t) in g.discretizeWithParams(maxDeviation: 1e-3) {
            let evaluated = g.evaluate(t)
            XCTAssertEqual(evaluated.x, point.x, accuracy: 1e-9)
            XCTAssertEqual(evaluated.y, point.y, accuracy: 1e-9)
        }
    }
}
