import XCTest
@testable import SketchKernel

/// Geometría de construcción (helper): no cierra regiones, pero sigue
/// snappable y seleccionable. Mecánica GeometryMode::Construction de FreeCAD.
final class ConstructionTests: XCTestCase {

    /// Un cuadrado cerrado da 1 región; si uno de sus lados es de construcción,
    /// deja de cerrar → 0 regiones.
    func testConstructionCurveDoesNotCloseRegion() {
        var m = SketchModel(mergeTolerance: 1e-3)
        m.addLine(from: Vec2(0, 0), to: Vec2(10, 0))
        m.addLine(from: Vec2(10, 0), to: Vec2(10, 10))
        m.addLine(from: Vec2(10, 10), to: Vec2(0, 10))
        let last = m.addLine(from: Vec2(0, 10), to: Vec2(0, 0))
        XCTAssertEqual(RegionFinder.regions(in: m).count, 1, "cuadrado normal cierra")

        m.setConstruction(last, true)
        XCTAssertTrue(RegionFinder.regions(in: m).isEmpty,
                      "un lado de construcción abre el perfil: ya no cierra")
    }

    /// Una diagonal de construcción DENTRO de un cuadrado cerrado no debe
    /// partirlo en dos regiones (no aporta aristas al arreglo).
    func testConstructionDiagonalDoesNotSplitRegion() {
        var m = SketchModel(mergeTolerance: 1e-3)
        m.addLine(from: Vec2(0, 0), to: Vec2(10, 0))
        m.addLine(from: Vec2(10, 0), to: Vec2(10, 10))
        m.addLine(from: Vec2(10, 10), to: Vec2(0, 10))
        m.addLine(from: Vec2(0, 10), to: Vec2(0, 0))
        let diag = m.addLine(from: Vec2(0, 0), to: Vec2(10, 10))
        m.setConstruction(diag, true)
        let regions = RegionFinder.regions(in: m)
        XCTAssertEqual(regions.count, 1, "la diagonal de construcción no parte el área")
        XCTAssertEqual(regions.first?.area ?? 0, 100, accuracy: 1e-6)
    }

    /// La curva de construcción sigue siendo snappable: su punto medio se
    /// engancha igual que el de cualquier trazo.
    func testConstructionCurveIsStillSnappable() {
        var m = SketchModel(mergeTolerance: 1e-3)
        let l = m.addLine(from: Vec2(0, 0), to: Vec2(10, 0))
        m.setConstruction(l, true)
        let engine = SnapEngine()
        let r = engine.snap(SnapContext(cursor: Vec2(5.2, 0.2), radius: 0.5), in: m)
        XCTAssertEqual(r.kind, .midpoint, "construcción no filtra el snap")
        XCTAssertEqual(r.position.distance(to: Vec2(5, 0)), 0, accuracy: 1e-9)
    }

    /// La curva de construcción sigue siendo seleccionable por hit-test.
    func testConstructionCurveIsStillHittable() {
        var m = SketchModel(mergeTolerance: 1e-3)
        let l = m.addLine(from: Vec2(0, 0), to: Vec2(10, 0))
        m.setConstruction(l, true)
        let hit = HitTester().hitTest(at: Vec2(5, 0.15), in: m,
                                      pointRadius: 0.1, curveRadius: 0.4)
        guard case .curve(let id, _) = hit else { return XCTFail("esperaba curva") }
        XCTAssertEqual(id, l)
    }

    /// El flag sobrevive un round-trip de Codable; documentos viejos sin la
    /// clave decodifican `false`.
    func testConstructionFlagCodableRoundTrip() throws {
        var m = SketchModel(mergeTolerance: 1e-3)
        let l = m.addLine(from: Vec2(0, 0), to: Vec2(10, 0))
        m.setConstruction(l, true)
        let data = try JSONEncoder().encode(m)
        let back = try JSONDecoder().decode(SketchModel.self, from: data)
        XCTAssertTrue(back.curves[l]?.isConstruction ?? false)
    }

    func testLegacyCurveJSONDecodesConstructionFalse() throws {
        // JSON de una curva SIN la clave isConstruction (formato anterior).
        let pid1 = PointID(), pid2 = PointID()
        let json = """
        {"id":{"raw":"\(CurveID().raw.uuidString)"},
         "kind":{"line":{"start":{"raw":"\(pid1.raw.uuidString)"},
                          "end":{"raw":"\(pid2.raw.uuidString)"}}}}
        """
        let curve = try JSONDecoder().decode(SketchCurve.self, from: Data(json.utf8))
        XCTAssertFalse(curve.isConstruction, "sin la clave → false por defecto")
    }
}
