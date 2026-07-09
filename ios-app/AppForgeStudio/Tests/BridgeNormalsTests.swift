import XCTest
import simd
import OCCTSwift
@testable import AppForgeStudio

/// Blindaje del sombreado: el bridge nativo de OCCTSwift rellena (0,0,1) cuando
/// la triangulación no trae normales → TODAS iguales → sombreado plano (los
/// objetos se veían como siluetas grises en device). OCCTBridge debe entregar
/// normales REALES por cara.
final class BridgeNormalsTests: XCTestCase {

    func testBoxMeshHasDistinctFaceNormals() throws {
        let shape = try XCTUnwrap(OCCTSwift.Shape.box(width: 2, height: 2, depth: 2))
        let mesh = try XCTUnwrap(OCCTBridge.toMesh(shape, quality: .medium))

        // Una caja tiene 6 orientaciones de normal; exigir al menos 3 distintas
        // (con 1 sola, el sombreado es plano — el bug de device).
        var distinct: [SIMD3<Float>] = []
        for v in mesh.vertices {
            XCTAssertEqual(simd_length(v.normal), 1.0, accuracy: 0.01, "normales unitarias")
            if !distinct.contains(where: { simd_distance($0, v.normal) < 0.1 }) {
                distinct.append(v.normal)
            }
        }
        XCTAssertGreaterThanOrEqual(distinct.count, 3,
            "una caja debe tener ≥3 direcciones de normal distintas (había 1: sombreado plano)")
    }

    func testBoxNormalsPointOutward() throws {
        let shape = try XCTUnwrap(OCCTSwift.Shape.box(width: 2, height: 2, depth: 2))
        let mesh = try XCTUnwrap(OCCTBridge.toMesh(shape, quality: .medium))

        // Caja centrada en el origen: la normal de cada vértice debe apuntar
        // HACIA AFUERA (dot(normal, posición) > 0 en los vértices de las caras).
        var outward = 0, total = 0
        for v in mesh.vertices where simd_length(v.position) > 0.5 {
            total += 1
            if simd_dot(v.normal, simd_normalize(v.position)) > 0 { outward += 1 }
        }
        XCTAssertGreaterThan(total, 0)
        XCTAssertGreaterThan(Float(outward) / Float(total), 0.9,
            "≥90% de las normales apuntan hacia afuera (winding correcto)")
    }

    func testComputeVertexNormalsOracle() {
        // Triángulo en el plano XY con winding CCW → normal +Z exacta
        let positions: [SIMD3<Float>] = [
            SIMD3<Float>(0, 0, 0), SIMD3<Float>(1, 0, 0), SIMD3<Float>(0, 1, 0)
        ]
        let normals = OCCTBridge.computeVertexNormals(positions: positions, indices: [0, 1, 2])
        for n in normals {
            XCTAssertEqual(n.x, 0, accuracy: 1e-5)
            XCTAssertEqual(n.y, 0, accuracy: 1e-5)
            XCTAssertEqual(n.z, 1, accuracy: 1e-5, "CCW en XY → normal +Z")
        }
    }
}
