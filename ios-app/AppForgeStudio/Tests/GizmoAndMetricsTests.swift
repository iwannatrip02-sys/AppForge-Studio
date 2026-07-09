import XCTest
import simd
import OCCTSwift
@testable import AppForgeStudio

/// Tests del tramo ÁREA 1b: gizmo procedural, rotación por eje arbitrario,
/// y métricas B-rep reales en la selección (estilo barra inferior de Shapr3D).
@MainActor
final class GizmoAndMetricsTests: XCTestCase {

    private func makeBoxModel() throws -> Model {
        let shape = try XCTUnwrap(OCCTSwift.Shape.box(width: 2, height: 2, depth: 2))
        let mesh = try XCTUnwrap(OCCTBridge.toMesh(shape, quality: .medium))
        let model = Model(name: "GBox")
        model.cadShape = shape
        model.meshes = [mesh]
        return model
    }

    func testArrowMeshIsRenderable() {
        let mesh = GizmoBuilder.arrowMesh(center: .zero, axis: SIMD3<Float>(1, 0, 0), length: 1.0)
        XCTAssertGreaterThan(mesh.vertices.count, 20, "flecha con cuerpo y punta")
        XCTAssertGreaterThan(mesh.indices.count, 30)
        XCTAssertEqual(mesh.indices.count % 3, 0, "triángulos completos")
        // La punta llega exactamente a length a lo largo del eje
        let maxX = mesh.vertices.map { $0.position.x }.max() ?? 0
        XCTAssertEqual(maxX, 1.0, accuracy: 1e-4, "la punta de la flecha está en length")
    }

    func testRingMeshIsRenderable() {
        let ring = GizmoBuilder.ringMesh(center: .zero, axis: SIMD3<Float>(0, 1, 0), radius: 1.0)
        XCTAssertGreaterThan(ring.vertices.count, 100, "anillo de 40 segmentos con tubo")
        XCTAssertEqual(ring.indices.count % 3, 0)
        // Todos los puntos del anillo ⊥Y viven cerca del plano y=0 (± tubo)
        for v in ring.vertices {
            XCTAssertLessThan(abs(v.position.y), 0.05, "anillo ⊥ eje Y vive en el plano y≈0")
        }
    }

    func testEdgesMeshForBoxIsSubstantial() throws {
        let shape = try XCTUnwrap(OCCTSwift.Shape.box(width: 2, height: 2, depth: 2))
        let edges = try XCTUnwrap(OCCTBridge.edgesMesh(shape),
                                  "una caja tiene 12 aristas → malla de aristas")
        // 12 aristas × 1 segmento × 8 vértices = 96 mínimo
        XCTAssertGreaterThanOrEqual(edges.vertices.count, 96)
        XCTAssertEqual(edges.indices.count % 3, 0)
        // Las aristas viven en el contorno: toda posición tiene al menos 2
        // coordenadas en ±1 (los bordes del cubo), con holgura del radio del tubo
        for v in edges.vertices.prefix(50) {
            let onBoundary = [abs(v.position.x), abs(v.position.y), abs(v.position.z)]
                .filter { abs($0 - 1.0) < 0.05 }.count
            XCTAssertGreaterThanOrEqual(onBoundary, 2,
                "los tubos de arista viven en los bordes del cubo")
        }
    }

    func testRotateAroundArbitraryAxisPreservesVolume() throws {
        let model = try makeBoxModel()
        XCTAssertTrue(BRepModeling.rotate(model, axis: SIMD3<Double>(1, 0, 0),
                                          angle: .pi / 3, center: .zero))
        let vol = try XCTUnwrap(try XCTUnwrap(model.cadShape).volume)
        XCTAssertEqual(vol, 8.0, accuracy: 0.01, "rotar sobre X no cambia el volumen")
    }

    func testEdgeSelectionReportsExactLength() throws {
        let model = try makeBoxModel()
        let sel = SelectionController()
        let edgePoint = SurfaceHit(modelIndex: 0, position: SIMD3<Float>(1, 0, 1),
                                   normal: SIMD3<Float>(1, 0, 0), distance: 1)
        sel.handleTap(hit: edgePoint, models: [model])   // v2: UN tap directo
        XCTAssertTrue(sel.statusMessage.contains("2.00"),
                      "la arista de la caja 2×2×2 mide EXACTAMENTE 2.00 — es: \(sel.statusMessage)")
    }

    func testFaceSelectionReportsExactArea() throws {
        let model = try makeBoxModel()
        let sel = SelectionController()
        let faceCenter = SurfaceHit(modelIndex: 0, position: SIMD3<Float>(0, 0, 1),
                                    normal: SIMD3<Float>(0, 0, 1), distance: 1)
        sel.handleTap(hit: faceCenter, models: [model])   // v2: UN tap directo
        XCTAssertTrue(sel.statusMessage.contains("4.00"),
                      "la cara de la caja 2×2 tiene área EXACTA 4.00 — es: \(sel.statusMessage)")
    }

    func testBodySelectionReportsVolume() throws {
        let model = try makeBoxModel()
        let sel = SelectionController()
        sel.handleTap(hit: SurfaceHit(modelIndex: 0, position: SIMD3<Float>(0, 0, 1),
                                      normal: SIMD3<Float>(0, 0, 1), distance: 1),
                      models: [model])
        sel.escalateToBody(models: [model])   // v2: botón "Cuerpo" escala
        XCTAssertTrue(sel.statusMessage.contains("8.00"),
                      "el cuerpo reporta volumen exacto 8.00 — es: \(sel.statusMessage)")
    }
}
