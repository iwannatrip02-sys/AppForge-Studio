import XCTest
import simd
import OCCTSwift
import SketchKernel
@testable import AppForgeStudio

/// Contrato de PERFIL ANALÍTICO: dibujar un círculo y extruirlo produce un
/// CILINDRO B-rep real, no un prisma de ~50 caras planas.
///
/// Por qué importa (feedback de device, jul-2026): "un cilindro no se ve
/// redondo" y "los objetos se separan por polígonos" NO eran problemas de
/// teselado ni de sombreado — la geometría misma era un polígono. `RegionFinder`
/// discretiza las curvas para armar el grafo planar, y ese polígono alimentaba
/// directamente la extrusión. Con la procedencia (`SketchRegion.boundary`) el
/// perfil se reconstruye con las curvas originales.
///
/// El oráculo es el CONTEO DE CARAS y el TIPO DE SUPERFICIE: un cilindro tiene
/// 3 caras (una cilíndrica + 2 tapas planas); el prisma viejo tenía ~52 planas.
/// Es binario y no admite interpretación.
@MainActor
final class AnalyticProfileTests: XCTestCase {

    // MARK: - Círculo → cilindro real

    func testExtrudedCircleIsARealCylinder() throws {
        let s = SketchController()
        s.beginTool(.circle)
        s.tap(at: SIMD2(0, 0))
        s.tap(at: SIMD2(1, 0))          // radio 1
        XCTAssertEqual(s.regions.count, 1)

        let model = try XCTUnwrap(s.extrudeProfile(height: 2.0))
        let shape = try XCTUnwrap(model.cadShape)

        let faces = shape.faces()
        XCTAssertEqual(faces.count, 3,
            "un cilindro son 3 caras (pared + 2 tapas); el prisma poligonal traía ~52")

        let cylindrical = faces.filter { $0.surfaceType == .cylinder }
        XCTAssertEqual(cylindrical.count, 1,
            "la pared debe ser una superficie CILÍNDRICA exacta, no N planos")

        let planar = faces.filter { $0.surfaceType == .plane }
        XCTAssertEqual(planar.count, 2, "las dos tapas son planas")
    }

    /// El volumen deja de ser una aproximación: el polígono inscrito SIEMPRE
    /// subestima (para R1 el error era ~1.6e-2), el cilindro real da π·r²·h.
    func testExtrudedCircleVolumeIsExact() throws {
        let s = SketchController()
        s.beginTool(.circle)
        s.tap(at: SIMD2(0, 0))
        s.tap(at: SIMD2(1, 0))

        let model = try XCTUnwrap(s.extrudeProfile(height: 2.0))
        let shape = try XCTUnwrap(model.cadShape)
        let volume = try XCTUnwrap(shape.volume)

        XCTAssertEqual(volume, .pi * 1 * 1 * 2, accuracy: 1e-6,
            "cilindro R1 h2 = 2π exacto (el perfil poligonal erraba ~1.6e-2)")
    }

    // MARK: - No romper lo que ya funcionaba

    func testExtrudedRectangleStaysSixPlanarFaces() throws {
        let s = SketchController()
        s.beginTool(.rectangle)
        s.tap(at: SIMD2(0, 0))
        s.tap(at: SIMD2(2, 3))

        let model = try XCTUnwrap(s.extrudeProfile(height: 1.5))
        let shape = try XCTUnwrap(model.cadShape)

        let faces = shape.faces()
        XCTAssertEqual(faces.count, 6, "una caja sigue siendo 6 caras")
        XCTAssertTrue(faces.allSatisfy { $0.surfaceType == .plane },
            "todas planas: el camino analítico no inventa curvatura donde no la hay")
        XCTAssertEqual(try XCTUnwrap(shape.volume), 2 * 3 * 1.5, accuracy: 1e-6)
    }

    // MARK: - Perfil mixto directo sobre el constructor

    /// Tres lados rectos + un semicírculo, extruido: 3 paredes planas + 1 pared
    /// CILÍNDRICA + 2 tapas. Ejercita `AnalyticProfileBuilder` con un contorno
    /// de curvas mezcladas, que es donde `Wire.join` tiene que coser bien.
    func testMixedProfileExtrudesWithCylindricalWall() throws {
        var m = SketchModel(mergeTolerance: 1e-3)
        m.addLine(from: Vec2(0, 0), to: Vec2(10, 0))
        m.addLine(from: Vec2(10, 0), to: Vec2(10, 10))
        m.addLine(from: Vec2(10, 10), to: Vec2(0, 10))
        m.addArc(center: Vec2(0, 5), start: Vec2(0, 10), end: Vec2(0, 0), ccw: true)

        let region = try XCTUnwrap(RegionFinder.regions(in: m, maxDeviation: 1e-3).first)
        XCTAssertEqual(region.boundary.count, 4, "el contorno conserva las 4 curvas")

        // Plano del piso: sketch (x,y) → mundo (x,0,y); normal +Y.
        let wire = try XCTUnwrap(
            AnalyticProfileBuilder.wire(boundary: region.boundary,
                                        in: m,
                                        origin: SIMD3<Double>(0, 0, 0),
                                        uAxis: SIMD3<Double>(1, 0, 0),
                                        vAxis: SIMD3<Double>(0, 0, 1),
                                        normal: SIMD3<Double>(0, 1, 0)),
            "el contorno mixto debe coserse en un wire cerrado")

        let solid = try XCTUnwrap(
            OCCTSwift.Shape.extrude(profile: wire,
                                    direction: SIMD3<Double>(0, 1, 0),
                                    length: 2))
        XCTAssertTrue(solid.isValid)

        let faces = solid.faces()
        XCTAssertEqual(faces.count, 6,
            "3 paredes planas + 1 pared cilíndrica + 2 tapas")
        XCTAssertEqual(faces.filter { $0.surfaceType == .cylinder }.count, 1,
            "el semicírculo debe producir UNA pared cilíndrica, no ~25 planas")

        // Volumen = (cuadrado 10×10 + medio disco R5) × altura 2.
        XCTAssertEqual(try XCTUnwrap(solid.volume),
                       (100 + .pi * 25 / 2) * 2, accuracy: 1e-4)
    }

    // MARK: - Degradación honesta

    /// Sin procedencia el constructor devuelve nil (y el llamador cae al
    /// polígono) en vez de inventarse geometría.
    func testBuilderReturnsNilWithoutBoundary() {
        let m = SketchModel()
        XCTAssertNil(AnalyticProfileBuilder.wire(boundary: [],
                                                 in: m,
                                                 origin: SIMD3<Double>(0, 0, 0),
                                                 uAxis: SIMD3<Double>(1, 0, 0),
                                                 vAxis: SIMD3<Double>(0, 0, 1),
                                                 normal: SIMD3<Double>(0, 1, 0)))
    }

    /// Una curva que ya no existe en el modelo tampoco produce basura.
    func testBuilderReturnsNilForUnknownCurve() {
        let m = SketchModel()
        let ghost = SketchKernel.RegionEdge(curveID: CurveID(), tStart: 0, tEnd: 1)
        XCTAssertNil(AnalyticProfileBuilder.wire(boundary: [ghost],
                                                 in: m,
                                                 origin: SIMD3<Double>(0, 0, 0),
                                                 uAxis: SIMD3<Double>(1, 0, 0),
                                                 vAxis: SIMD3<Double>(0, 0, 1),
                                                 normal: SIMD3<Double>(0, 1, 0)))
    }
}
