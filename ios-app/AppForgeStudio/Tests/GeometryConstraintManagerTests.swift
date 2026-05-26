import XCTest
@testable import AppForgeStudio

final class GeometryConstraintManagerTests: XCTestCase {
    var manager: GeometryConstraintManager!

    override func setUp() {
        super.setUp()
        manager = GeometryConstraintManager()
    }

    // MARK: - Evaluate Constraint Tests

    func testEvaluateHorizontalConstraint() {
        let constraint = GeometryConstraint(type: .horizontal, entityIDs: [UUID()])
        let pos: [UUID: SIMD3<Float>] = [constraint.entityIDs[0]: SIMD3<Float>(1, 2, 3)]
        let residual = manager.evaluateConstraint(constraint, positions: pos)
        XCTAssertEqual(residual, 2.0, accuracy: 0.001)
    }

    func testEvaluateVerticalConstraint() {
        let constraint = GeometryConstraint(type: .vertical, entityIDs: [UUID()])
        let pos: [UUID: SIMD3<Float>] = [constraint.entityIDs[0]: SIMD3<Float>(5, 1, 2)]
        let residual = manager.evaluateConstraint(constraint, positions: pos)
        XCTAssertEqual(residual, 5.0, accuracy: 0.001)
    }

    func testEvaluateDistanceConstraint() {
        let id1 = UUID()
        let id2 = UUID()
        let constraint = GeometryConstraint(type: .distance, entityIDs: [id1, id2], value: 10.0)
        let pos: [UUID: SIMD3<Float>] = [id1: .zero, id2: SIMD3<Float>(3, 4, 0)]
        let residual = manager.evaluateConstraint(constraint, positions: pos)
        XCTAssertEqual(residual, 5.0, accuracy: 0.001)
    }

    func testEvaluateAngleConstraint() {
        let apex = UUID()
        let p1 = UUID()
        let p2 = UUID()
        let constraint = GeometryConstraint(type: .angle, entityIDs: [apex, p1, p2], value: 90.0)
        let pos: [UUID: SIMD3<Float>] = [apex: .zero, p1: SIMD3<Float>(1, 0, 0), p2: SIMD3<Float>(0, 0, 1)]
        let residual = manager.evaluateConstraint(constraint, positions: pos)
        XCTAssertEqual(residual, 0.0, accuracy: 0.001)
    }

    func testEvaluatePerpendicularConstraint() {
        let id1 = UUID()
        let id2 = UUID()
        let constraint = GeometryConstraint(type: .perpendicular, entityIDs: [id1, id2])
        let pos: [UUID: SIMD3<Float>] = [id1: SIMD3<Float>(1, 0, 0), id2: SIMD3<Float>(0, 1, 0)]
        let residual = manager.evaluateConstraint(constraint, positions: pos)
        XCTAssertEqual(residual, 0.0, accuracy: 0.001)
    }

    func testEvaluateEqualConstraint() {
        let id1 = UUID()
        let id2 = UUID()
        let constraint = GeometryConstraint(type: .equal, entityIDs: [id1, id2])
        let pos: [UUID: SIMD3<Float>] = [id1: SIMD3<Float>(3, 0, 0), id2: SIMD3<Float>(0, 4, 0)]
        let residual = manager.evaluateConstraint(constraint, positions: pos)
        XCTAssertEqual(residual, 1.0, accuracy: 0.001)
    }

    func testEvaluateMidpointConstraint() {
        let p1 = UUID()
        let p2 = UUID()
        let p3 = UUID()
        let constraint = GeometryConstraint(type: .midpoint, entityIDs: [p1, p2, p3])
        let pos: [UUID: SIMD3<Float>] = [p1: .zero, p2: SIMD3<Float>(2, 0, 0), p3: SIMD3<Float>(1, 0, 0)]
        let residual = manager.evaluateConstraint(constraint, positions: pos)
        XCTAssertEqual(residual, 0.0, accuracy: 0.001)
    }

    func testEvaluateConcentricConstraint() {
        let id1 = UUID()
        let id2 = UUID()
        let constraint = GeometryConstraint(type: .concentric, entityIDs: [id1, id2])
        let pos: [UUID: SIMD3<Float>] = [id1: .zero, id2: SIMD3<Float>(5, 0, 0)]
        let residual = manager.evaluateConstraint(constraint, positions: pos)
        XCTAssertEqual(residual, 5.0, accuracy: 0.001)
    }

    func testEvaluateCollinearConstraint() {
        let p1 = UUID()
        let p2 = UUID()
        let p3 = UUID()
        let constraint = GeometryConstraint(type: .collinear, entityIDs: [p1, p2, p3])
        let pos: [UUID: SIMD3<Float>] = [p1: .zero, p2: SIMD3<Float>(2, 0, 0), p3: SIMD3<Float>(1, 0, 0)]
        let residual = manager.evaluateConstraint(constraint, positions: pos)
        XCTAssertEqual(residual, 0.0, accuracy: 0.001)
    }

    // MARK: - Solve Tests

    func testSolveSingleConstraintUpdatesPositions() {
        let id = UUID()
        let constraint = GeometryConstraint(type: .horizontal, entityIDs: [id])
        manager.addConstraint(constraint)
        var positions: [UUID: SIMD3<Float>] = [id: SIMD3<Float>(1, 5, 3)]
        let residual = manager.solve(positions: &positions)
        XCTAssertLessThan(residual, 0.001)
        XCTAssertEqual(positions[id]?.y, 0.0, accuracy: 0.001)
    }

    func testResolveConstraintsConverges() {
        let id = UUID()
        let constraint = GeometryConstraint(type: .vertical, entityIDs: [id])
        manager.addConstraint(constraint)
        manager.entityPositionProvider = { _ in SIMD3<Float>(3, 1, 2) }
        manager.entityPositionUpdater = { _, newPos in }
        manager.resolveConstraints()
        XCTAssertFalse(manager.isSolving)
        XCTAssertGreaterThanOrEqual(manager.lastIterationCount, 1)
    }

    func testAddRemoveUpdateConstraint() {
        let c1 = GeometryConstraint(type: .horizontal, entityIDs: [UUID()])
        let c2 = GeometryConstraint(type: .vertical, entityIDs: [UUID()])
        manager.addConstraint(c1)
        manager.addConstraint(c2)
        XCTAssertEqual(manager.constraintCount, 2)
        manager.removeConstraint(at: c1.id)
        XCTAssertEqual(manager.constraintCount, 1)
        var updated = c2
        updated.label = "Test"
        manager.updateConstraint(updated)
        XCTAssertEqual(manager.constraints.first?.label, "Test")
    }

    func testToggleConstraint() {
        let c = GeometryConstraint(type: .horizontal, entityIDs: [UUID()])
        manager.addConstraint(c)
        XCTAssertTrue(c.isActive)
        manager.toggleConstraint(c.id)
        XCTAssertFalse(manager.constraints.first?.isActive ?? true)
    }

    func testAllFunctions() {
        let c1 = GeometryConstraint(type: .horizontal, entityIDs: [UUID()])
        let c2 = GeometryConstraint(type: .vertical, entityIDs: [UUID()])
        manager.addConstraint(c1)
        manager.addConstraint(c2)
        XCTAssertEqual(manager.allFunctions.count, 2)
    }

    func testClearAll() {
        manager.addConstraint(GeometryConstraint(type: .horizontal, entityIDs: [UUID()]))
        manager.addConstraint(GeometryConstraint(type: .vertical, entityIDs: [UUID()]))
        manager.clearAll()
        XCTAssertEqual(manager.constraintCount, 0)
    }
}