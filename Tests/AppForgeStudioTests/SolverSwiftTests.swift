import XCTest
@testable import AppForgeStudio

final class SolverSwiftTests: XCTestCase {

    func testEmptyConstraints() {
        let solver = SolverSwift()
        let result = solver.solve()
        XCTAssertTrue(result.converged)
    }

    func testFixedPoint() {
        let solver = SolverSwift()
        let p0 = SolverPoint(id: UUID(), x: 0, y: 0, isFixed: true)
        solver.addPoint(p0)
        solver.addConstraint(SolverConstraint(id: UUID(), type: .horizontal(pointID: p0.id), weight: 1.0))
        let result = solver.solve()
        XCTAssertTrue(result.converged)
        if let p = result.points.first(where: { $0.id == p0.id }) {
            XCTAssertEqual(p.x, 0, accuracy: 1e-6)
            XCTAssertEqual(p.y, 0, accuracy: 1e-6)
        }
    }

    func testDistanceConstraint() {
        let solver = SolverSwift()
        let originID = UUID()
        let freeID = UUID()
        let origin = SolverPoint(id: originID, x: 0, y: 0, isFixed: true)
        let free = SolverPoint(id: freeID, x: 3, y: 4, isFixed: false)
        solver.addPoint(origin)
        solver.addPoint(free)
        solver.addConstraint(SolverConstraint(id: UUID(), type: .distance(pointA: originID, pointB: freeID, value: 5.0), weight: 1.0))
        let result = solver.solve()
        XCTAssertTrue(result.converged)
        if let p = result.points.first(where: { $0.id == freeID }) {
            let dist = sqrt(p.x * p.x + p.y * p.y)
            XCTAssertEqual(dist, 5.0, accuracy: 1e-4)
        }
    }

    func testHorizontalConstraint() {
        let solver = SolverSwift()
        let originID = UUID()
        let freeID = UUID()
        let origin = SolverPoint(id: originID, x: 0, y: 0, isFixed: true)
        let free = SolverPoint(id: freeID, x: 3, y: 7, isFixed: false)
        solver.addPoint(origin)
        solver.addPoint(free)
        solver.addConstraint(SolverConstraint(id: UUID(), type: .horizontal(pointID: freeID), weight: 1.0))
        solver.addConstraint(SolverConstraint(id: UUID(), type: .distance(pointA: originID, pointB: freeID, value: 5.0), weight: 1.0))
        let result = solver.solve()
        XCTAssertTrue(result.converged)
        if let p = result.points.first(where: { $0.id == freeID }) {
            XCTAssertEqual(p.y, 0, accuracy: 1e-4)
            let dist = sqrt(p.x * p.x + p.y * p.y)
            XCTAssertEqual(dist, 5.0, accuracy: 1e-4)
        }
    }

    func testTriangleEquilateral() {
        let solver = SolverSwift()
        let p0 = SolverPoint(id: UUID(), x: 0, y: 0, isFixed: true)
        let p1 = SolverPoint(id: UUID(), x: 1, y: 0, isFixed: true)
        let p2 = SolverPoint(id: UUID(), x: 0.5, y: 0.5, isFixed: false)
        solver.addPoint(p0)
        solver.addPoint(p1)
        solver.addPoint(p2)
        solver.addConstraint(SolverConstraint(id: UUID(), type: .distance(pointA: p0.id, pointB: p2.id, value: 1.0), weight: 1.0))
        solver.addConstraint(SolverConstraint(id: UUID(), type: .distance(pointA: p1.id, pointB: p2.id, value: 1.0), weight: 1.0))
        let result = solver.solve()
        XCTAssertTrue(result.converged)
        if let p = result.points.first(where: { $0.id == p2.id }) {
            let expectedX = 0.5
            let expectedY = sqrt(0.75)
            XCTAssertEqual(p.x, expectedX, accuracy: 1e-4)
            XCTAssertEqual(p.y, expectedY, accuracy: 1e-4)
        }
    }
}
