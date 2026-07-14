import XCTest
import simd
import OCCTSwift
@testable import AppForgeStudio

/// Tests PUROS del resolver selección → objetivo de transform
/// (`TransformTargetResolver`, Sources/Services/TransformTarget.swift).
///
/// Verifican el contrato que consume la capa de vista (gizmo + drag):
///   1. el ÚLTIMO sub-objeto tocado manda sobre el cuerpo escalado,
///   2. el centroide del objetivo es resoluble para un cuerpo real (anclaje del gizmo),
///   3. la honestidad: arista/vértice NO pretenden geometría (`supportsRealGeometry`).
/// Sin device: solo geometría OCCT en proceso (`Shape.box`).
@MainActor
final class TransformTargetResolverTests: XCTestCase {

    private func makeBoxModel() throws -> Model {
        let shape = try XCTUnwrap(OCCTSwift.Shape.box(width: 2, height: 2, depth: 2))
        let mesh = try XCTUnwrap(OCCTBridge.toMesh(shape, quality: .medium))
        let model = Model(name: "TBox")
        model.cadShape = shape
        model.meshes = [mesh]
        return model
    }

    // MARK: - target(lastItem:bodyIndex:)

    func testFaceLastItemResolvesToFaceTarget() {
        let item = SelectionController.Item.face(modelIndex: 0, faceIndex: 3)
        let target = TransformTargetResolver.target(lastItem: item, bodyIndex: nil)
        XCTAssertEqual(target, .face(modelIndex: 0, faceIndex: 3),
                       "una cara seleccionada resuelve a objetivo .face")
    }

    func testSubObjectWinsOverBodyIndex() {
        // El sub-objeto tocado manda aunque haya un bodyIndex activo.
        let item = SelectionController.Item.edge(modelIndex: 1, edgeIndex: 2)
        let target = TransformTargetResolver.target(lastItem: item, bodyIndex: 5)
        XCTAssertEqual(target, .edge(modelIndex: 1, edgeIndex: 2))
    }

    func testBodyIndexResolvesToBodyWhenNoSubObject() {
        let target = TransformTargetResolver.target(lastItem: nil, bodyIndex: 4)
        XCTAssertEqual(target, .body(modelIndex: 4))
    }

    func testNilSelectionResolvesToNil() {
        XCTAssertNil(TransformTargetResolver.target(lastItem: nil, bodyIndex: nil))
    }

    // MARK: - center(for:in:)

    func testCenterIsNonNilForBoxBody() throws {
        let model = try makeBoxModel()
        let center = TransformTargetResolver.center(for: .body(modelIndex: 0), in: [model])
        let c = try XCTUnwrap(center, "el centroide del cuerpo debe resolver para un box con malla")
        // El box está centrado en el origen: el centro del bbox ≈ .zero.
        XCTAssertEqual(c.x, 0, accuracy: 1e-3)
        XCTAssertEqual(c.y, 0, accuracy: 1e-3)
        XCTAssertEqual(c.z, 0, accuracy: 1e-3)
    }

    func testCenterOutOfRangeIndexIsNil() throws {
        let model = try makeBoxModel()
        XCTAssertNil(TransformTargetResolver.center(for: .body(modelIndex: 9), in: [model]),
                     "índice fuera de rango → nil, sin crash")
    }

    // MARK: - supportsRealGeometry (honestidad)

    func testEdgeDoesNotClaimRealGeometry() {
        XCTAssertFalse(TransformTarget.edge(modelIndex: 0, edgeIndex: 0).supportsRealGeometry,
                       "arista: aún no deforma geometría — estado honesto")
    }

    func testVertexDoesNotClaimRealGeometry() {
        XCTAssertFalse(TransformTarget.vertex(modelIndex: 0, vertexIndex: 0).supportsRealGeometry)
    }

    func testBodyAndFaceClaimRealGeometry() {
        XCTAssertTrue(TransformTarget.body(modelIndex: 0).supportsRealGeometry)
        XCTAssertTrue(TransformTarget.face(modelIndex: 0, faceIndex: 0).supportsRealGeometry,
                      "cara: push/pull vía BRepModeling.pushPullFace")
    }

    func testFaceAndBodyAreSubObjectClassifiedCorrectly() {
        XCTAssertFalse(TransformTarget.body(modelIndex: 0).isSubObject)
        XCTAssertTrue(TransformTarget.face(modelIndex: 0, faceIndex: 0).isSubObject)
    }
}
