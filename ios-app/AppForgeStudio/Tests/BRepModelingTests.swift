import XCTest
import simd
import OCCTSwift
@testable import AppForgeStudio

/// Tests del núcleo B-rep (BRepModeling) — la base de ingeniería real de la app.
/// Los oráculos son VOLÚMENES EXACTOS que solo un kernel B-rep puede garantizar:
/// una malla de juguete no puede fingirlos.
final class BRepModelingTests: XCTestCase {

    /// Modelo con B-rep vivo a partir de una caja OCCT.
    private func makeBoxModel(width: Double, height: Double, depth: Double,
                              name: String = "Box") throws -> Model {
        let shape = try XCTUnwrap(OCCTSwift.Shape.box(width: width, height: height, depth: depth))
        let mesh = try XCTUnwrap(OCCTBridge.toMesh(shape, quality: .medium))
        let model = Model(name: name)
        model.cadShape = shape
        model.meshes = [mesh]
        return model
    }

    private func volume(of model: Model) throws -> Double {
        try XCTUnwrap(try XCTUnwrap(model.cadShape).volume)
    }

    // MARK: - Booleanos B-rep entre modelos

    private func makeOverlappingBoxes() throws -> (Model, Model) {
        let a = try makeBoxModel(width: 2, height: 2, depth: 2, name: "A")
        let b = try makeBoxModel(width: 2, height: 2, depth: 2, name: "B")
        // Desplazar B una unidad en X: solape = 1×2×2 = 4
        let shifted = try XCTUnwrap(try XCTUnwrap(b.cadShape).translated(by: SIMD3<Double>(1, 0, 0)))
        b.cadShape = shifted
        return (a, b)
    }

    func testBooleanUnionExactVolume() throws {
        let (a, b) = try makeOverlappingBoxes()
        let result = try XCTUnwrap(BRepModeling.boolean(.booleanUnion, a, b))
        // 8 + 8 - 4 solape = 12
        XCTAssertEqual(try volume(of: result), 12.0, accuracy: 0.01)
        XCTAssertNotNil(result.cadShape, "el resultado debe conservar su B-rep")
        XCTAssertFalse(result.meshes.first?.vertices.isEmpty ?? true, "y traer malla de display")
    }

    func testBooleanSubtractExactVolume() throws {
        let (a, b) = try makeOverlappingBoxes()
        let result = try XCTUnwrap(BRepModeling.boolean(.booleanSubtract, a, b))
        XCTAssertEqual(try volume(of: result), 4.0, accuracy: 0.01)
    }

    func testBooleanIntersectExactVolume() throws {
        let (a, b) = try makeOverlappingBoxes()
        let result = try XCTUnwrap(BRepModeling.boolean(.booleanIntersect, a, b))
        XCTAssertEqual(try volume(of: result), 4.0, accuracy: 0.01)
    }

    func testBooleanWithoutBRepReturnsNilForFallback() throws {
        let a = try makeBoxModel(width: 1, height: 1, depth: 1)
        let b = Model(name: "SinBRep")  // sin cadShape (p.ej. modelo esculpido)
        XCTAssertNil(BRepModeling.boolean(.booleanUnion, a, b),
                     "sin B-rep en ambos, debe devolver nil para que el caller haga fallback a malla")
    }

    // MARK: - Push/Pull real (boss/pocket)

    func testPushPullBossAddsExactVolume() throws {
        let model = try makeBoxModel(width: 2, height: 2, depth: 2)
        let shape = try XCTUnwrap(model.cadShape)
        let faceIdx = try XCTUnwrap(
            BRepModeling.faceIndex(of: shape, withNormal: SIMD3<Double>(0, 0, 1)),
            "la caja debe tener una cara con normal +Z")

        let pushed = try XCTUnwrap(BRepModeling.pushPullFace(shape, faceIndex: faceIdx, distance: 1.0))
        // Boss de 2×2×1 sobre la cara: 8 + 4 = 12
        XCTAssertEqual(try XCTUnwrap(pushed.volume), 12.0, accuracy: 0.05)
    }

    func testPushPullPocketRemovesExactVolume() throws {
        let model = try makeBoxModel(width: 2, height: 2, depth: 2)
        let shape = try XCTUnwrap(model.cadShape)
        let faceIdx = try XCTUnwrap(
            BRepModeling.faceIndex(of: shape, withNormal: SIMD3<Double>(0, 0, 1)))

        let cut = try XCTUnwrap(BRepModeling.pushPullFace(shape, faceIndex: faceIdx, distance: -1.0))
        // Pocket de 2×2×1: 8 - 4 = 4
        XCTAssertEqual(try XCTUnwrap(cut.volume), 4.0, accuracy: 0.05)
    }

    func testPushPullInvalidFaceReturnsNil() throws {
        let model = try makeBoxModel(width: 1, height: 1, depth: 1)
        let shape = try XCTUnwrap(model.cadShape)
        XCTAssertNil(BRepModeling.pushPullFace(shape, faceIndex: 999, distance: 1))
        XCTAssertNil(BRepModeling.pushPullFace(shape, faceIndex: 0, distance: 0))
    }

    // MARK: - Features in-place (fillet / chamfer / shell)

    func testFilletReducesVolumeSlightly() throws {
        let model = try makeBoxModel(width: 2, height: 2, depth: 2)
        let before = try volume(of: model)
        XCTAssertTrue(BRepModeling.fillet(model, radius: 0.2))
        let after = try volume(of: model)
        XCTAssertLessThan(after, before, "el fillet quita material de las aristas")
        XCTAssertGreaterThan(after, before * 0.9, "pero solo un poco (r=0.2 en caja de 2)")
    }

    func testChamferReducesVolume() throws {
        let model = try makeBoxModel(width: 2, height: 2, depth: 2)
        let before = try volume(of: model)
        XCTAssertTrue(BRepModeling.chamfer(model, distance: 0.2))
        XCTAssertLessThan(try volume(of: model), before)
    }

    func testShellHollowsTheSolid() throws {
        let model = try makeBoxModel(width: 2, height: 2, depth: 2)
        let before = try volume(of: model)
        XCTAssertTrue(BRepModeling.shell(model, thickness: 0.1),
                      "shell con cara abierta automática debe aplicar")
        let after = try volume(of: model)
        XCTAssertLessThan(after, before * 0.6,
                          "el shell vacía el sólido: queda mucho menos material que el sólido lleno")
        XCTAssertGreaterThan(after, 0.1, "pero las paredes tienen material")
    }

    func testApplyFeatureRefreshesMeshInPlace() throws {
        let model = try makeBoxModel(width: 2, height: 2, depth: 2)
        let vertsBefore = model.meshes.first?.vertices.count ?? 0
        XCTAssertTrue(BRepModeling.fillet(model, radius: 0.3))
        let vertsAfter = model.meshes.first?.vertices.count ?? 0
        XCTAssertNotEqual(vertsBefore, vertsAfter,
                          "la malla de display debe re-triangularse tras la feature")
    }

    func testFailedFeatureDoesNotMutateModel() throws {
        let model = try makeBoxModel(width: 1, height: 1, depth: 1)
        let before = try volume(of: model)
        // Radio absurdo (mayor que la caja) → OCCT falla → el modelo queda intacto
        let applied = BRepModeling.fillet(model, radius: 50)
        if !applied {
            XCTAssertEqual(try volume(of: model), before, accuracy: 1e-9,
                           "una feature fallida no debe tocar el B-rep ni la malla")
        }
    }

    // MARK: - STEP real

    func testExportSTEPWritesRealBRepFile() throws {
        let model = try makeBoxModel(width: 1, height: 1, depth: 1)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("brep_\(UUID().uuidString).step")
        defer { try? FileManager.default.removeItem(at: url) }

        XCTAssertTrue(BRepModeling.exportSTEP(model, to: url))
        let content = try String(contentsOf: url, encoding: .utf8)
        XCTAssertTrue(content.contains("ISO-10303-21"), "cabecera STEP válida")
        XCTAssertTrue(content.contains("MANIFOLD_SOLID_BREP") || content.contains("ADVANCED_BREP"),
                      "STEP real de sólido B-rep, no polyloops sintetizados de malla")
    }

    func testExportSTEPWithoutBRepReturnsFalse() {
        let model = Model(name: "SinBRep")
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("no_brep_\(UUID().uuidString).step")
        XCTAssertFalse(BRepModeling.exportSTEP(model, to: url))
    }
}
