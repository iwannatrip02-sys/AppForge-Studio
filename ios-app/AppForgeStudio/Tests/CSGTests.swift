import XCTest
import OCCTSwift
@testable import AppForgeStudio

/// CSG sobre el kernel real (OCCTSwift B-rep).
/// Sustituye a los tests del Shape BSP legacy — Sources/LegacyCSG ya no es parte del target.
final class CSGTests: XCTestCase {

    /// Triangula un shape y valida invariantes básicos de la malla resultante.
    @discardableResult
    private func meshOrFail(_ shape: OCCTSwift.Shape?, _ label: String) throws -> Mesh {
        let mesh = try XCTUnwrap(shape.flatMap { OCCTBridge.toMesh($0, quality: .medium) },
                                 "\(label): no se pudo triangular")
        XCTAssertFalse(mesh.vertices.isEmpty, "\(label): sin vértices")
        XCTAssertFalse(mesh.indices.isEmpty, "\(label): sin índices")
        XCTAssertEqual(mesh.indices.count % 3, 0, "\(label): índices no múltiplo de 3")
        return mesh
    }

    // MARK: - Primitivas

    func testBoxPrimitiveProducesValidMesh() throws {
        try meshOrFail(OCCTSwift.Shape.box(width: 2, height: 2, depth: 2), "box")
    }

    func testCylinderPrimitiveProducesValidMesh() throws {
        try meshOrFail(OCCTSwift.Shape.cylinder(radius: 1, height: 2), "cylinder")
    }

    func testSpherePrimitiveProducesValidMesh() throws {
        try meshOrFail(OCCTSwift.Shape.sphere(radius: 1), "sphere")
    }

    func testConePrimitiveProducesValidMesh() throws {
        try meshOrFail(OCCTSwift.Shape.cone(bottomRadius: 1, topRadius: 0.5, height: 2), "cone")
    }

    func testTorusPrimitiveProducesValidMesh() throws {
        try meshOrFail(OCCTSwift.Shape.torus(majorRadius: 1, minorRadius: 0.3), "torus")
    }

    func testDegenerateSphereReturnsNil() {
        XCTAssertNil(OCCTSwift.Shape.sphere(radius: 0), "esfera de radio 0 debe fallar")
    }

    // MARK: - Booleanos

    private func twoOverlappingBoxes() throws -> (OCCTSwift.Shape, OCCTSwift.Shape) {
        let a = try XCTUnwrap(OCCTSwift.Shape.box(width: 2, height: 2, depth: 2))
        let bBase = try XCTUnwrap(OCCTSwift.Shape.box(width: 2, height: 2, depth: 2))
        let b = try XCTUnwrap(bBase.translated(by: SIMD3<Double>(1, 0, 0)))
        return (a, b)
    }

    func testUnionOfTwoBoxesProducesValidMesh() throws {
        let (a, b) = try twoOverlappingBoxes()
        try meshOrFail(a + b, "union")
    }

    func testDifferenceOfTwoBoxesProducesValidMesh() throws {
        let (a, b) = try twoOverlappingBoxes()
        try meshOrFail(a - b, "difference")
    }

    func testIntersectionOfTwoBoxesProducesValidMesh() throws {
        let (a, b) = try twoOverlappingBoxes()
        try meshOrFail(a & b, "intersection")
    }

    // MARK: - Propiedades geométricas (el B-rep permite asserts exactos)

    func testBoxVolumeIsExact() throws {
        let box = try XCTUnwrap(OCCTSwift.Shape.box(width: 2, height: 2, depth: 2))
        let volume = try XCTUnwrap(box.volume)
        XCTAssertEqual(volume, 8.0, accuracy: 0.01, "volumen de caja 2×2×2 debe ser 8")
    }

    func testUnionVolumeOfOverlappingBoxes() throws {
        let (a, b) = try twoOverlappingBoxes()
        let union = try XCTUnwrap(a + b)
        let volume = try XCTUnwrap(union.volume)
        // Dos cajas de 8 con solape de 1×2×2=4 → 8+8-4 = 12
        XCTAssertEqual(volume, 12.0, accuracy: 0.05, "volumen de unión con solape")
    }

    func testIntersectionVolumeOfOverlappingBoxes() throws {
        let (a, b) = try twoOverlappingBoxes()
        let intersection = try XCTUnwrap(a & b)
        let volume = try XCTUnwrap(intersection.volume)
        XCTAssertEqual(volume, 4.0, accuracy: 0.05, "volumen de intersección (solape 1×2×2)")
    }

    func testDifferenceVolumeOfOverlappingBoxes() throws {
        let (a, b) = try twoOverlappingBoxes()
        let difference = try XCTUnwrap(a - b)
        let volume = try XCTUnwrap(difference.volume)
        XCTAssertEqual(volume, 4.0, accuracy: 0.05, "volumen de diferencia (8 - solape 4)")
    }

    // MARK: - Bridge OCCT → Mesh propio

    func testBridgeProducesFiniteGeometry() throws {
        let mesh = try meshOrFail(OCCTSwift.Shape.sphere(radius: 1), "sphere-bridge")
        for v in mesh.vertices {
            XCTAssertTrue(v.position.x.isFinite && v.position.y.isFinite && v.position.z.isFinite,
                          "posiciones deben ser finitas")
        }
        let maxIndex = mesh.indices.max() ?? 0
        XCTAssertLessThan(Int(maxIndex), mesh.vertices.count, "índices dentro de rango")
    }
}
