import XCTest
@testable import AppForgeStudio

/// Tests para el sistema de cotas 3D (Oleada 1).
/// Verifica: cálculo de valores, formato, CRUD de anotaciones, proyección.
final class DimensionAnnotationTests: XCTestCase {

    // MARK: - Compute values

    func testLinearDimension() {
        let ann = DimensionAnnotation(
            type: .linear,
            anchorPoints: [
                SIMD3<Float>(0, 0, 0),
                SIMD3<Float>(3, 4, 0)
            ]
        )
        XCTAssertEqual(ann.measuredValue, 5.0, accuracy: 0.001)
        XCTAssertTrue(ann.label.contains("5.00"))
        XCTAssertTrue(ann.label.contains("mm"))
    }

    func testLinearDimensionSamePoint() {
        let ann = DimensionAnnotation(
            type: .linear,
            anchorPoints: [
                SIMD3<Float>(1, 1, 1),
                SIMD3<Float>(1, 1, 1)
            ]
        )
        XCTAssertEqual(ann.measuredValue, 0.0, accuracy: 0.001)
    }

    func testRadiusDimension() {
        let ann = DimensionAnnotation(
            type: .radius,
            anchorPoints: [
                SIMD3<Float>(0, 0, 0),  // centro
                SIMD3<Float>(0, 2.5, 0) // borde
            ]
        )
        XCTAssertEqual(ann.measuredValue, 2.5, accuracy: 0.001)
        XCTAssertTrue(ann.label.contains("R"))
        XCTAssertTrue(ann.label.contains("2.50"))
    }

    func testDiameterDimension() {
        let ann = DimensionAnnotation(
            type: .diameter,
            anchorPoints: [
                SIMD3<Float>(0, 0, 0),
                SIMD3<Float>(0, 3.0, 0)
            ]
        )
        XCTAssertEqual(ann.measuredValue, 6.0, accuracy: 0.001)
        XCTAssertTrue(ann.label.contains("⌀"))
    }

    func testAngleDimension() {
        let ann = DimensionAnnotation(
            type: .angle,
            anchorPoints: [
                SIMD3<Float>(0, 0, 0),  // vértice
                SIMD3<Float>(1, 0, 0),  // punto A (0°)
                SIMD3<Float>(0, 1, 0)   // punto B (90°)
            ]
        )
        XCTAssertEqual(ann.measuredValue, 90.0, accuracy: 0.1)
        XCTAssertTrue(ann.label.contains("°"))
    }

    func testAngle45Degrees() {
        let ann = DimensionAnnotation(
            type: .angle,
            anchorPoints: [
                SIMD3<Float>(0, 0, 0),
                SIMD3<Float>(1, 0, 0),
                SIMD3<Float>(1, 1, 0)
            ]
        )
        XCTAssertEqual(ann.measuredValue, 45.0, accuracy: 0.1)
    }

    // MARK: - Recompute

    func testRecomputeAfterAnchorChange() {
        var ann = DimensionAnnotation(
            type: .linear,
            anchorPoints: [
                SIMD3<Float>(0, 0, 0),
                SIMD3<Float>(1, 0, 0)
            ]
        )
        XCTAssertEqual(ann.measuredValue, 1.0, accuracy: 0.001)

        ann.anchorPoints[1] = SIMD3<Float>(10, 0, 0)
        ann.recompute()
        XCTAssertEqual(ann.measuredValue, 10.0, accuracy: 0.001)
        XCTAssertTrue(ann.label.contains("10.00"))
    }

    // MARK: - DimensionManager

    @MainActor
    func testAddLinearAnnotation() {
        let manager = DimensionManager()
        let ann = manager.addLinear(
            from: SIMD3<Float>(0, 0, 0),
            to: SIMD3<Float>(5, 0, 0)
        )
        XCTAssertEqual(manager.annotations.count, 1)
        XCTAssertEqual(manager.activeAnnotationID, ann.id)
        XCTAssertEqual(ann.type, .linear)
    }

    @MainActor
    func testAddRadiusAnnotation() {
        let manager = DimensionManager()
        let ann = manager.addRadius(
            center: SIMD3<Float>(0, 0, 0),
            edgePoint: SIMD3<Float>(0, 1.5, 0)
        )
        XCTAssertEqual(ann.type, .radius)
        XCTAssertEqual(ann.measuredValue, 1.5, accuracy: 0.001)
        // El color de radio es azul
        XCTAssertEqual(ann.color.z, 1.0, accuracy: 0.01)
    }

    @MainActor
    func testAddAngleAnnotation() {
        let manager = DimensionManager()
        let ann = manager.addAngle(
            vertex: SIMD3<Float>(0, 0, 0),
            pointA: SIMD3<Float>(1, 0, 0),
            pointB: SIMD3<Float>(0, 1, 0)
        )
        XCTAssertEqual(ann.type, .angle)
        XCTAssertEqual(ann.measuredValue, 90.0, accuracy: 0.1)
    }

    @MainActor
    func testUpdateActiveEndpoint() {
        let manager = DimensionManager()
        manager.addLinear(from: SIMD3<Float>(0, 0, 0), to: SIMD3<Float>(1, 0, 0))
        manager.updateActiveEndpoint(SIMD3<Float>(5, 0, 0))
        XCTAssertEqual(manager.annotations.first?.measuredValue, 5.0, accuracy: 0.001)
    }

    @MainActor
    func testRemoveActive() {
        let manager = DimensionManager()
        manager.addLinear(from: .zero, to: SIMD3<Float>(1, 0, 0))
        XCTAssertEqual(manager.annotations.count, 1)
        manager.removeActive()
        XCTAssertEqual(manager.annotations.count, 0)
        XCTAssertNil(manager.activeAnnotationID)
    }

    @MainActor
    func testClearAll() {
        let manager = DimensionManager()
        manager.addLinear(from: .zero, to: SIMD3<Float>(1, 0, 0))
        manager.addRadius(center: .zero, edgePoint: SIMD3<Float>(2, 0, 0))
        XCTAssertEqual(manager.annotations.count, 2)
        manager.clearAll()
        XCTAssertEqual(manager.annotations.count, 0)
    }

    @MainActor
    func testAnnotationsNear() {
        let manager = DimensionManager()
        manager.addLinear(
            from: SIMD3<Float>(0, 0, 0),
            to: SIMD3<Float>(10, 0, 0)
        )
        manager.addLinear(
            from: SIMD3<Float>(100, 0, 0),
            to: SIMD3<Float>(110, 0, 0)
        )

        let near = manager.annotationsNear(SIMD3<Float>(0, 0, 0), maxDistance: 1.0)
        XCTAssertEqual(near.count, 1)

        let far = manager.annotationsNear(SIMD3<Float>(200, 0, 0), maxDistance: 1.0)
        XCTAssertEqual(far.count, 0)
    }

    // MARK: - Projection

    func testViewportProjectorProjectsPoint() {
        let cam = Scene3D.Camera(
            position: SIMD3<Float>(0, 0, 5),
            target: .zero,
            up: SIMD3<Float>(0, 1, 0),
            fov: 45,
            nearPlane: 0.1,
            farPlane: 100
        )
        let viewMatrix = SatinRenderer.viewMatrix(for: cam)
        let projectionMatrix = SatinRenderer.projectionMatrix(for: cam, aspect: 1.0)
        let projector = ViewportProjector(
            viewMatrix: viewMatrix,
            projectionMatrix: projectionMatrix,
            viewportSize: CGSize(width: 768, height: 1024)
        )

        // Origen debe proyectar al centro de pantalla
        let screenCenter = projector.project(.zero)
        XCTAssertNotNil(screenCenter)
        XCTAssertEqual(screenCenter!.x, 384, accuracy: 5)
        XCTAssertEqual(screenCenter!.y, 512, accuracy: 5)
    }

    func testViewportProjectorBehindCameraIsNil() {
        let cam = Scene3D.Camera(
            position: SIMD3<Float>(0, 0, 5),
            target: SIMD3<Float>(0, 0, 0),
            up: SIMD3<Float>(0, 1, 0),
            fov: 45,
            nearPlane: 0.1,
            farPlane: 100
        )
        let viewMatrix = SatinRenderer.viewMatrix(for: cam)
        let projectionMatrix = SatinRenderer.projectionMatrix(for: cam, aspect: 1.0)
        let projector = ViewportProjector(
            viewMatrix: viewMatrix,
            projectionMatrix: projectionMatrix,
            viewportSize: CGSize(width: 100, height: 100)
        )

        // Punto detrás de la cámara
        let behind = projector.project(SIMD3<Float>(0, 0, 10))
        XCTAssertNil(behind)
    }
}
