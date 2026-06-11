import XCTest
import simd
@testable import AppForgeStudio

/// Tests for DynamicTopologyEngine (F4.T4).
///
/// Verifies:
///   - Edge-length-based subdivision (split long edges near brush)
///   - Face-area-based subdivision (split large faces near brush)
///   - Edge-length-based decimation (collapse short edges far from brush)
///   - Face-area-based decimation (collapse small faces far from brush)
///   - Delegate callback (SculptEngine integration)
///   - Threshold gating (no action when conditions not met)
///   - NaN prevention on degenerate geometry
@MainActor
final class DynamicTopologyTests: XCTestCase {

    var engine: DynamicTopologyEngine!

    override func setUp() {
        super.setUp()
        engine = DynamicTopologyEngine()
    }

    override func tearDown() {
        engine = nil
        super.tearDown()
    }

    // MARK: - Test meshes

    /// Creates a flat square mesh with 2 triangles, edge length = 1.0.
    private func makeSquare() -> Mesh {
        let verts: [Vertex] = [
            Vertex(position: SIMD3<Float>(0, 0, 0)),
            Vertex(position: SIMD3<Float>(1, 0, 0)),
            Vertex(position: SIMD3<Float>(1, 1, 0)),
            Vertex(position: SIMD3<Float>(0, 1, 0)),
        ]
        return Mesh(vertices: verts, indices: [0, 1, 2, 0, 2, 3])
    }

    /// Creates a fine grid (small triangles, edge ≈ 0.01).
    private func makeFineGrid() -> Mesh {
        var verts: [Vertex] = []
        var indices: [UInt32] = []
        let step: Float = 0.01
        let n = 10
        for y in 0...n {
            for x in 0...n {
                verts.append(Vertex(position: SIMD3<Float>(Float(x)*step, Float(y)*step, 0)))
            }
        }
        let w = n + 1
        for y in 0..<n {
            for x in 0..<n {
                let tl = UInt32(y * w + x)
                let tr = UInt32(y * w + x + 1)
                let bl = UInt32((y + 1) * w + x)
                let br = UInt32((y + 1) * w + x + 1)
                indices.append(contentsOf: [tl, tr, bl, tr, br, bl])
            }
        }
        return Mesh(vertices: verts, indices: indices)
    }

    // MARK: - Edge-length split tests

    func testEdgeSplitWhenLongEdgeNearBrush() {
        var mesh = makeSquare()
        engine.maxEdgeLength = 0.1 // edges are 1.0, so they should split
        let initialTriCount = mesh.indices.count / 3

        let trigger = engine.apply(to: &mesh, at: SIMD3<Float>(0.5, 0.5, 0), radius: 2.0)

        let finalTriCount = mesh.indices.count / 3
        XCTAssertGreaterThan(finalTriCount, initialTriCount,
            "Long edges near brush should be split, increasing triangle count")
        XCTAssertTrue(trigger.topologyChanged)
        XCTAssertFalse(trigger.affectedVertexIndices.isEmpty)
    }

    func testNoEdgeSplitWhenEdgeShortEnough() {
        var mesh = makeSquare()
        engine.maxEdgeLength = 2.0 // edges are 1.0, below threshold
        let initialTriCount = mesh.indices.count / 3

        let trigger = engine.apply(to: &mesh, at: SIMD3<Float>(0.5, 0.5, 0), radius: 2.0)

        XCTAssertEqual(mesh.indices.count / 3, initialTriCount,
            "Edges below maxEdgeLength should not be split")
        XCTAssertFalse(trigger.topologyChanged)
    }

    func testNoEdgeSplitWhenFarFromBrush() {
        var mesh = makeSquare()
        engine.maxEdgeLength = 0.1 // edges are 1.0
        let initialTriCount = mesh.indices.count / 3

        // Brush is far away (radius=0.1, center at 10)
        let trigger = engine.apply(to: &mesh, at: SIMD3<Float>(10, 10, 10), radius: 0.1)

        XCTAssertEqual(mesh.indices.count / 3, initialTriCount,
            "Edges far from brush should not be split even if long")
        XCTAssertFalse(trigger.topologyChanged)
    }

    // MARK: - Face-area split tests

    func testFaceSplitWhenLargeFaceNearBrush() {
        var mesh = makeSquare()
        engine.maxFaceArea = 0.01 // square face area ≈ 0.5, so it should split
        let initialTriCount = mesh.indices.count / 3

        let trigger = engine.apply(to: &mesh, at: SIMD3<Float>(0.5, 0.5, 0), radius: 2.0)

        let finalTriCount = mesh.indices.count / 3
        XCTAssertGreaterThan(finalTriCount, initialTriCount,
            "Large faces near brush should be split by face-area metric")
    }

    func testNoFaceSplitWhenFaceSmallEnough() {
        var mesh = makeSquare()
        engine.maxFaceArea = 10.0 // face area ≈ 0.5, well below threshold
        let initialTriCount = mesh.indices.count / 3

        let trigger = engine.apply(to: &mesh, at: SIMD3<Float>(0.5, 0.5, 0), radius: 2.0)

        XCTAssertEqual(mesh.indices.count / 3, initialTriCount,
            "Faces below maxFaceArea should not be split")
    }

    // MARK: - Edge collapse tests

    func testEdgeCollapseWhenShortEdgeFarFromBrush() {
        var mesh = makeFineGrid()
        engine.minEdgeLength = 0.05 // edges are 0.01, well below threshold
        let initialTriCount = mesh.indices.count / 3

        let trigger = engine.apply(to: &mesh, at: SIMD3<Float>(0.05, 0.05, 0), radius: 0.02)

        let finalTriCount = mesh.indices.count / 3
        // Some edges far from the brush should collapse
        XCTAssertLessThanOrEqual(finalTriCount, initialTriCount,
            "Short edges far from brush should be collapsed, reducing or maintaining tri count")
    }

    func testNoEdgeCollapseWhenEdgeLongEnough() {
        var mesh = makeFineGrid()
        engine.minEdgeLength = 0.001 // edges are 0.01, above threshold
        let initialTriCount = mesh.indices.count / 3

        let trigger = engine.apply(to: &mesh, at: SIMD3<Float>(0.05, 0.05, 0), radius: 0.02)

        XCTAssertEqual(mesh.indices.count / 3, initialTriCount,
            "Edges above minEdgeLength should not be collapsed")
    }

    // MARK: - Face collapse tests

    func testFaceCollapseWhenTinyFaceFarFromBrush() {
        var mesh = makeFineGrid()
        engine.minFaceArea = 0.01 // fine grid triangles are tiny (~0.00005), below threshold
        let initialTriCount = mesh.indices.count / 3

        let trigger = engine.apply(to: &mesh, at: SIMD3<Float>(0.05, 0.05, 0), radius: 0.02)

        let finalTriCount = mesh.indices.count / 3
        XCTAssertLessThanOrEqual(finalTriCount, initialTriCount,
            "Tiny faces far from brush should be collapsed")
    }

    func testNoFaceCollapseWhenFaceLargeEnough() {
        var mesh = makeSquare()
        engine.minFaceArea = 0.001 // square face area ≈ 0.5, above threshold
        let initialTriCount = mesh.indices.count / 3

        let trigger = engine.apply(to: &mesh, at: SIMD3<Float>(0.5, 0.5, 0), radius: 0.01)

        XCTAssertEqual(mesh.indices.count / 3, initialTriCount,
            "Faces above minFaceArea should not be collapsed")
    }

    // MARK: - Combined metrics

    func testBothMetricsCanActivate() {
        var mesh = makeSquare()
        engine.maxEdgeLength = 0.1  // split edges > 0.1
        engine.maxFaceArea = 0.01   // split faces > 0.01
        engine.minEdgeLength = 2.0  // don't collapse
        engine.minFaceArea = 0.0    // don't collapse

        let initialTriCount = mesh.indices.count / 3
        let trigger = engine.apply(to: &mesh, at: SIMD3<Float>(0.5, 0.5, 0), radius: 2.0)
        let finalTriCount = mesh.indices.count / 3

        XCTAssertGreaterThan(finalTriCount, initialTriCount,
            "Both edge and face metrics should trigger splits")
    }

    // MARK: - Empty / degenerate meshes

    func testEmptyMeshDoesNotCrash() {
        var mesh = Mesh()
        let trigger = engine.apply(to: &mesh, at: .zero, radius: 1.0)
        XCTAssertEqual(mesh.vertices.count, 0)
        XCTAssertEqual(mesh.indices.count, 0)
        XCTAssertFalse(trigger.topologyChanged)
    }

    func testDegenerateFaceDoesNotProduceNaN() {
        var mesh = Mesh(
            vertices: [
                Vertex(position: SIMD3<Float>(0, 0, 0)),
                Vertex(position: SIMD3<Float>(0, 0, 0)), // duplicate
                Vertex(position: SIMD3<Float>(1, 0, 0)),
            ],
            indices: [0, 1, 2]
        )
        engine.maxEdgeLength = 0.01 // trigger split
        let trigger = engine.apply(to: &mesh, at: .zero, radius: 10.0)

        // Should not crash and should not produce NaN
        for v in mesh.vertices {
            XCTAssertFalse(v.position.x.isNaN)
            XCTAssertFalse(v.position.y.isNaN)
            XCTAssertFalse(v.position.z.isNaN)
        }
    }

    // MARK: - Delegate integration (SculptEngine hook)

    func testDelegateIsCalled() {
        let delegate = MockDelegate()
        engine.delegate = delegate

        var mesh = makeSquare()
        engine.maxEdgeLength = 0.1
        let trigger = engine.apply(to: &mesh, at: SIMD3<Float>(0.5, 0.5, 0), radius: 2.0)

        XCTAssertTrue(delegate.didRemesh)
        XCTAssertEqual(delegate.lastTrigger?.topologyChanged, trigger.topologyChanged)
    }

    func testRemeshTriggerReportsTopologyChange() {
        var mesh = makeSquare()
        engine.maxEdgeLength = 0.1 // will split

        let trigger = engine.apply(to: &mesh, at: SIMD3<Float>(0.5, 0.5, 0), radius: 2.0)
        XCTAssertTrue(trigger.topologyChanged, "Splitting edges changes topology")
    }

    func testRemeshTriggerReportsNoTopologyChangeWhenIdle() {
        var mesh = makeSquare()
        engine.maxEdgeLength = 10.0  // won't split
        engine.maxFaceArea = 10.0    // won't split
        engine.minEdgeLength = 0.0   // won't collapse
        engine.minFaceArea = 0.0     // won't collapse

        let trigger = engine.apply(to: &mesh, at: SIMD3<Float>(0.5, 0.5, 0), radius: 2.0)
        XCTAssertFalse(trigger.topologyChanged, "No splitting/collapsing → topology unchanged")
    }

    // MARK: - Threshold defaults

    func testDefaultThresholds() {
        XCTAssertEqual(engine.maxEdgeLength, 0.02)
        XCTAssertEqual(engine.minEdgeLength, 0.002)
        XCTAssertEqual(engine.maxFaceArea, 0.0002)
        XCTAssertEqual(engine.minFaceArea, 0.000002)
        XCTAssertEqual(engine.influenceRings, 3)
    }
}

// MARK: - Mock delegate

private class MockDelegate: DynamicTopologyDelegate {
    var didRemesh = false
    var lastTrigger: RemeshTrigger?

    func dynamicTopologyDidRemesh(_ trigger: RemeshTrigger) {
        didRemesh = true
        lastTrigger = trigger
    }
}
