import XCTest
import simd
import OCCTSwift
@testable import AppForgeStudio

/// Oráculos de las transformaciones directas (Mover/Rotar/Escalar horneadas al
/// B-rep — Ola Transformar). El B-rep es la fuente de verdad: tras el bake, el
/// picking y las booleanas deben operar sobre la geometría YA transformada.
@MainActor
final class TransformBakeTests: XCTestCase {

    private func makeBoxModel() throws -> Model {
        let shape = try XCTUnwrap(OCCTSwift.Shape.box(width: 2, height: 2, depth: 2))
        let mesh = try XCTUnwrap(OCCTBridge.toMesh(shape, quality: .medium))
        let model = Model(name: "TBox")
        model.cadShape = shape
        model.meshes = [mesh]
        return model
    }

    private func centroid(_ model: Model) throws -> SIMD3<Float> {
        let verts = try XCTUnwrap(model.meshes.first?.vertices)
        XCTAssertFalse(verts.isEmpty)
        var acc = SIMD3<Float>.zero
        for v in verts { acc += v.position }
        return acc / Float(verts.count)
    }

    private func volume(_ model: Model) throws -> Double {
        try XCTUnwrap(try XCTUnwrap(model.cadShape).volume)
    }

    func testTranslateMovesBRepExactly() throws {
        let model = try makeBoxModel()
        let v0 = model.geometryVersion

        XCTAssertTrue(BRepModeling.translate(model, by: SIMD3<Double>(2, 0, 0)))
        XCTAssertEqual(try volume(model), 8.0, accuracy: 0.01, "trasladar no cambia el volumen")
        let c = try centroid(model)
        XCTAssertEqual(c.x, 2.0, accuracy: 0.05, "el centroide se movió exactamente +2 en X")
        XCTAssertEqual(c.y, 0.0, accuracy: 0.05)
        XCTAssertGreaterThan(model.geometryVersion, v0, "el bake invalida los buffers GPU")
    }

    func testRotateYPreservesVolumeAndCenter() throws {
        let model = try makeBoxModel()
        XCTAssertTrue(BRepModeling.rotateY(model, angle: .pi / 4, center: .zero))
        XCTAssertEqual(try volume(model), 8.0, accuracy: 0.01, "rotar no cambia el volumen")
        let c = try centroid(model)
        XCTAssertEqual(simd_length(c), 0.0, accuracy: 0.05, "pivote en el centro → centroide quieto")
    }

    func testScaleUniformVolumeOracle() throws {
        let model = try makeBoxModel()
        XCTAssertTrue(BRepModeling.scaleUniform(model, factor: 2.0, center: .zero))
        XCTAssertEqual(try volume(model), 64.0, accuracy: 0.1, "escala 2 → volumen ×8 (2³)")
        let c = try centroid(model)
        XCTAssertEqual(simd_length(c), 0.0, accuracy: 0.05, "pivote en el centro → centroide quieto")
    }

    func testScaleRejectsNonPositiveFactor() throws {
        let model = try makeBoxModel()
        XCTAssertFalse(BRepModeling.scaleUniform(model, factor: 0, center: .zero))
        XCTAssertEqual(try volume(model), 8.0, accuracy: 0.01, "el modelo no se muta si falla")
    }
}
