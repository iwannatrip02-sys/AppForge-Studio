import XCTest
@testable import SketchKernel

/// Contratos de ESCALA y DETERMINISMO del kernel.
///
/// Los bugs que cazan estos tests son de la peor familia para un CAD: no
/// revientan, no avisan, y devuelven un resultado distinto según el tamaño del
/// dibujo o según el humor del runtime. En una app donde el usuario hace zoom
/// libremente y las unidades del plano son arbitrarias, eso es inaceptable.
final class ScaleAndDeterminismTests: XCTestCase {

    // MARK: - El paralelismo no puede depender del tamaño

    /// Dos segmentos PERPENDICULARES minúsculos se cruzan igual que dos grandes.
    /// El test de paralelismo comparaba el producto cruz (unidades de longitud²)
    /// contra una tolerancia absoluta, así que a escala pequeña los declaraba
    /// paralelos y perdía la intersección.
    func testTinyPerpendicularSegmentsStillIntersect() throws {
        let s = 1e-5
        let x = try XCTUnwrap(
            Intersections.segmentSegment(Vec2(0, 0), Vec2(s, 0),
                                         Vec2(s / 2, -s / 2), Vec2(s / 2, s / 2)),
            "dos perpendiculares de longitud 1e-5 SÍ se cruzan")
        XCTAssertEqual(x.x, s / 2, accuracy: s * 1e-6)
        XCTAssertEqual(x.y, 0, accuracy: s * 1e-6)
    }

    /// El mismo cruce a escala grande da el mismo resultado relativo: el
    /// criterio es invariante a escala.
    func testHugePerpendicularSegmentsIntersectToo() throws {
        let s = 1e5
        let x = try XCTUnwrap(
            Intersections.segmentSegment(Vec2(0, 0), Vec2(s, 0),
                                         Vec2(s / 2, -s / 2), Vec2(s / 2, s / 2)))
        XCTAssertEqual(x.x, s / 2, accuracy: s * 1e-6)
    }

    /// Y los realmente paralelos se siguen rechazando a cualquier escala.
    func testParallelSegmentsAreStillRejectedAtEveryScale() {
        for s in [1e-5, 1.0, 1e5] {
            XCTAssertNil(Intersections.segmentSegment(Vec2(0, 0), Vec2(s, 0),
                                                      Vec2(0, s), Vec2(s, s)),
                         "paralelos a escala \(s) no tienen punto único")
        }
    }

    func testDegenerateSegmentIsRejected() {
        XCTAssertNil(Intersections.segmentSegment(Vec2(0, 0), Vec2(0, 0),
                                                  Vec2(-1, 0), Vec2(1, 0)),
                     "un segmento de longitud cero no define intersección")
    }

    /// Un cruce a escala pequeña también debe partir bien las regiones — es el
    /// camino real por el que el bug llegaba al usuario (trim y regiones usan
    /// `segmentSegment` sobre segmentos discretizados).
    func testSmallCrossingRectanglesStillSplitIntoRegions() {
        var m = SketchModel(mergeTolerance: 1e-9)
        func rect(_ a: Vec2, _ b: Vec2) {
            m.addLine(from: a, to: Vec2(b.x, a.y))
            m.addLine(from: Vec2(b.x, a.y), to: b)
            m.addLine(from: b, to: Vec2(a.x, b.y))
            m.addLine(from: Vec2(a.x, b.y), to: a)
        }
        let u = 1e-4                     // pieza diminuta
        rect(Vec2(0, 0), Vec2(2 * u, 2 * u))
        rect(Vec2(u, u), Vec2(3 * u, 3 * u))

        let regions = RegionFinder.regions(in: m, maxDeviation: u * 1e-3,
                                           weldTolerance: u * 1e-4)
        XCTAssertGreaterThanOrEqual(regions.count, 3,
            "dos rectángulos que se solapan parten en ≥3 regiones también a 1e-4")
    }

    // MARK: - El snap tiene que ser reproducible

    /// Con más fuentes de alineación que el tope, las que sobreviven al recorte
    /// deben ser SIEMPRE las mismas — antes salían de un diccionario, cuyo orden
    /// de iteración no está garantizado, así que la guía aparecía o no al azar.
    func testAlignmentGuidesAreDeterministicAcrossRuns() {
        var m = SketchModel(mergeTolerance: 1e-9)
        // Muchos más puntos que `maxAlignmentSources` (64).
        for i in 0..<200 {
            let t = Double(i)
            m.addLine(from: Vec2(t * 0.37, 5 + t * 0.11),
                      to: Vec2(t * 0.37 + 0.2, 5 + t * 0.11 + 0.2))
        }
        // Un punto cuya X coincide con el cursor → debe generar alineación V.
        m.addLine(from: Vec2(10, 40), to: Vec2(10.2, 40.2))

        let engine = SnapEngine()
        let ctx = SnapContext(cursor: Vec2(10, 0), radius: 0.05)

        let first = engine.activeGuides(ctx, in: m,
                                        geometries: m.orderedCurves.compactMap {
                                            CurveGeometry.resolve($0, in: m)
                                        })
        for _ in 0..<12 {
            let again = engine.activeGuides(ctx, in: m,
                                            geometries: m.orderedCurves.compactMap {
                                                CurveGeometry.resolve($0, in: m)
                                            })
            XCTAssertEqual(again.count, first.count,
                           "el mismo cursor debe producir SIEMPRE las mismas guías")
            for (a, b) in zip(first, again) {
                XCTAssertEqual(a.kind, b.kind)
                XCTAssertEqual(a.through.x, b.through.x, accuracy: 1e-12)
                XCTAssertEqual(a.through.y, b.through.y, accuracy: 1e-12)
            }
        }
    }

    // MARK: - El hit-test también tiene que ser reproducible

    /// Tocar EXACTAMENTE en medio de dos puntos simétricos debe elegir siempre
    /// el mismo. `model.positions` es un diccionario y el desempate era "el
    /// primero que salga", o sea aleatorio. Los sketches simétricos son comunes
    /// —más desde que existe el espejo— así que el empate es alcanzable.
    func testEquidistantPointHitIsDeterministic() {
        var m = SketchModel(mergeTolerance: 1e-9)
        m.addLine(from: Vec2(-1, 0), to: Vec2(-1, 1))
        m.addLine(from: Vec2(1, 0), to: Vec2(1, 1))

        let tester = HitTester()
        let cursor = Vec2(0, 0)          // equidistante de (−1,0) y (1,0)
        var seen = Set<String>()
        for _ in 0..<15 {
            guard case .point(_, let pos) = tester.hitTest(at: cursor, in: m,
                                                           pointRadius: 2,
                                                           curveRadius: 0.1) else {
                return XCTFail("debe enganchar uno de los dos puntos")
            }
            seen.insert("\(pos.x),\(pos.y)")
        }
        XCTAssertEqual(seen.count, 1,
                       "el mismo toque debe elegir SIEMPRE el mismo punto; vi \(seen)")
    }

    /// El doble tap de perímetro no debe arrastrar geometría de CONSTRUCCIÓN:
    /// un eje suele tocar el perfil, y llevárselo a la selección hace que
    /// Espejo u Offset actúen sobre helpers.
    func testConnectedChainDoesNotCrossIntoConstructionGeometry() {
        var m = SketchModel(mergeTolerance: 1e-9)
        let a = m.addLine(from: Vec2(0, 0), to: Vec2(4, 0))
        let b = m.addLine(from: Vec2(4, 0), to: Vec2(4, 4))
        // Eje de construcción que ARRANCA en una esquina del perfil.
        let axis = m.addLine(from: Vec2(0, 0), to: Vec2(0, 9))
        m.setConstruction(axis, true)

        let chain = HitTester().connectedChain(from: a, in: m)
        XCTAssertTrue(chain.contains(a))
        XCTAssertTrue(chain.contains(b), "el perfil real sí encadena")
        XCTAssertFalse(chain.contains(axis),
                       "la cadena no cruza a geometría de construcción")
    }

    /// Y al revés: partiendo de un eje de construcción se encadenan ejes, no
    /// el perfil.
    func testConstructionChainStaysInConstruction() {
        var m = SketchModel(mergeTolerance: 1e-9)
        let real = m.addLine(from: Vec2(0, 0), to: Vec2(4, 0))
        let axis1 = m.addLine(from: Vec2(0, 0), to: Vec2(0, 5))
        let axis2 = m.addLine(from: Vec2(0, 5), to: Vec2(3, 5))
        m.setConstruction(axis1, true)
        m.setConstruction(axis2, true)

        let chain = HitTester().connectedChain(from: axis1, in: m)
        XCTAssertTrue(chain.contains(axis2), "los ejes encadenan entre sí")
        XCTAssertFalse(chain.contains(real), "pero no saltan al perfil")
    }

    /// Y el recorte se queda con las fuentes CERCANAS, que son las relevantes:
    /// una alineación a tiro del cursor no puede perderse porque otras 200
    /// lejanas ocuparan el cupo.
    func testNearAlignmentSurvivesTheSourceCap() {
        var m = SketchModel(mergeTolerance: 1e-9)
        for i in 0..<200 {
            let t = Double(i)
            m.addLine(from: Vec2(500 + t, 500 + t), to: Vec2(500 + t + 0.1, 500 + t))
        }
        // Punto CERCA del cursor y alineado en X con él.
        m.addLine(from: Vec2(3, 9), to: Vec2(3.1, 9))

        let engine = SnapEngine()
        let ctx = SnapContext(cursor: Vec2(3, 0), radius: 0.1)
        let guides = engine.activeGuides(ctx, in: m,
                                         geometries: m.orderedCurves.compactMap {
                                             CurveGeometry.resolve($0, in: m)
                                         })
        XCTAssertTrue(guides.contains { $0.kind == .alignmentV },
                      "la alineación cercana sobrevive al tope de fuentes")
    }
}
