import XCTest
@testable import AppForgeStudio

final class SculptDeformerTests: XCTestCase {

    // MARK: - Mini-mesh helpers

    /// Creates a flat quad of 4 vertices at z=0, forming 2 triangles.
    /// Positions: (0,0,0), (1,0,0), (1,1,0), (0,1,0). All normals point +Z.
    func makeQuadVertices() -> [Vertex] {
        [
            Vertex(position: SIMD3<Float>(0, 0, 0), normal: SIMD3<Float>(0, 0, 1), uv: .zero),
            Vertex(position: SIMD3<Float>(1, 0, 0), normal: SIMD3<Float>(0, 0, 1), uv: .zero),
            Vertex(position: SIMD3<Float>(1, 1, 0), normal: SIMD3<Float>(0, 0, 1), uv: .zero),
            Vertex(position: SIMD3<Float>(0, 1, 0), normal: SIMD3<Float>(0, 0, 1), uv: .zero),
        ]
    }

    func makeQuadMesh() -> Mesh {
        let verts = makeQuadVertices()
        let indices: [UInt32] = [0, 1, 2, 0, 2, 3]
        return Mesh(vertices: verts, indices: indices)
    }

    /// SculptEngine with radius large enough to cover the whole quad (diagonal ≈ 1.42).
    func makeEngine(deformer: DeformerType) -> SculptEngine {
        let engine = SculptEngine()
        engine.setDeformer(deformer)
        engine.radius = 2.0
        engine.strength = 1.0
        return engine
    }

    // MARK: - BUG7 Regression: Grab deformer dragDelta

    /// BUG7: When dragDelta is non-null, displacement must follow dragDelta,
    /// NOT (point.position - vertex.position).
    /// Verified API — SculptEngine.applyDeformer(.grab) line: Sources/Engines/SculptEngine.swift:94
    func testGrabDeformerNonZeroDragDeltaMovesAllVerticesInDragDeltaDirection() {
        // GIVEN a quad and a SculptPoint at center with dragDelta pointing +Z
        var vertices = makeQuadVertices()
        let engine = makeEngine(deformer: .grab)
        let origPositions = vertices.map { $0.position }

        let point = SculptPoint(
            position: SIMD3<Float>(0.5, 0.5, 0.0),
            normal: SIMD3<Float>(0, 0, 1),
            pressure: 1.0,
            dragDelta: SIMD3<Float>(0, 0, 1)  // non-zero → use dragDelta path
        )

        // WHEN applying grab
        engine.apply(at: point, to: &vertices)

        // THEN every vertex shifted in +Z (dragDelta direction), not toward point.position
        for (i, v) in vertices.enumerated() {
            let orig = origPositions[i]
            // Original positions were at z=0; now z should be > 0
            XCTAssertGreaterThan(v.position.z, orig.z,
                "Vertex \(i) should move in +Z (dragDelta direction)")
            // Position should NOT have moved toward the sculpt point in XY
            // (that would indicate fallback path using point.position - vertex.position)
            // The dragDelta path applies same displacement to all vertices, so XY differences
            // between original and new positions should be zero
            XCTAssertEqual(v.position.x, orig.x, accuracy: 1e-6,
                "Vertex \(i) X should be unchanged (dragDelta has no X component)")
            XCTAssertEqual(v.position.y, orig.y, accuracy: 1e-6,
                "Vertex \(i) Y should be unchanged (dragDelta has no Y component)")
        }
    }

    /// BUG7: When dragDelta ≈ 0, the fallback uses (point.position - vertex.position).
    /// Verified API — SculptEngine.applyDeformer(.grab) line: Sources/Engines/SculptEngine.swift:94
    func testGrabDeformerZeroDragDeltaFallsBackToPositionDelta() {
        // GIVEN a quad and a SculptPoint with dragDelta ≈ 0
        var vertices = makeQuadVertices()
        let engine = makeEngine(deformer: .grab)

        let sculptPos = SIMD3<Float>(0.5, 0.5, 1.0)
        let point = SculptPoint(
            position: sculptPos,
            normal: SIMD3<Float>(0, 0, 1),
            pressure: 1.0,
            dragDelta: SIMD3<Float>(0, 0, 0)  // zero → fallback path
        )

        // WHEN applying grab
        engine.apply(at: point, to: &vertices)

        // THEN each vertex moves toward the sculpt point (point.position - vertex.position)
        for (i, v) in vertices.enumerated() {
            // The fallback displacement = point.position - vertex.position
            // This means near vertices (like (0.5,0.5,0)) get small XY displacement,
            // far vertices (like (0,0,0)) get larger XY displacement toward (0.5,0.5)
            // Key assertion: the Z component should increase (moved toward point at z=1)
            XCTAssertGreaterThan(v.position.z, 0.0,
                "Vertex \(i) should move in +Z toward sculpt point at z=1")
        }
    }

    // MARK: - Inflate deformer smoke tests

    /// Inflate pushes vertices outward along their normals.
    /// Verified API — Sources/Engines/SculptEngine.swift:85
    func testInflateDeformerPushesVerticesAlongNormals() {
        // GIVEN a quad with normals pointing +Z
        var vertices = makeQuadVertices()
        let engine = makeEngine(deformer: .inflate)
        let origPositions = vertices.map { $0.position }

        let point = SculptPoint(
            position: SIMD3<Float>(0.5, 0.5, 0.0),
            normal: SIMD3<Float>(0, 0, 1),
            pressure: 1.0,
            dragDelta: .zero
        )

        // WHEN applying inflate
        engine.apply(at: point, to: &vertices)

        // THEN all Z components increase (pushed along +Z normals), XY unchanged
        for (i, v) in vertices.enumerated() {
            let orig = origPositions[i]
            XCTAssertGreaterThan(v.position.z, orig.z,
                "Vertex \(i) Z should increase (inflate along normal)")
            XCTAssertEqual(v.position.x, orig.x, accuracy: 1e-5,
                "Vertex \(i) X should stay the same for +Z normals")
            XCTAssertEqual(v.position.y, orig.y, accuracy: 1e-5,
                "Vertex \(i) Y should stay the same for +Z normals")
        }
    }

    /// Verify inflate produces no NaN values.
    func testInflateDeformerProducesNoNaN() {
        var vertices = makeQuadVertices()
        let engine = makeEngine(deformer: .inflate)

        let point = SculptPoint(
            position: SIMD3<Float>(0.5, 0.5, 0.0),
            normal: SIMD3<Float>(0, 0, 1),
            pressure: 1.0,
            dragDelta: .zero
        )

        engine.apply(at: point, to: &vertices)

        for (i, v) in vertices.enumerated() {
            XCTAssertFalse(v.position.x.isNaN, "Vertex \(i) position.x is NaN")
            XCTAssertFalse(v.position.y.isNaN, "Vertex \(i) position.y is NaN")
            XCTAssertFalse(v.position.z.isNaN, "Vertex \(i) position.z is NaN")
            XCTAssertTrue(v.position.x.isFinite, "Vertex \(i) position.x is not finite")
            XCTAssertTrue(v.position.y.isFinite, "Vertex \(i) position.y is not finite")
            XCTAssertTrue(v.position.z.isFinite, "Vertex \(i) position.z is not finite")
        }
    }

    // MARK: - Smooth deformer smoke tests

    /// Smooth without adjacency mixes vertex position toward the sculpt point.
    /// Verified API — Sources/Engines/SmoothDeformer.swift:17
    func testSmoothDeformerWithoutAdjacencyMovesTowardPoint() {
        var vertices = makeQuadVertices()
        let engine = makeEngine(deformer: .smooth)

        // Place sculpt point far above the quad so movement direction is clear
        let point = SculptPoint(
            position: SIMD3<Float>(0.5, 0.5, 2.0),
            normal: SIMD3<Float>(0, 0, 1),
            pressure: 1.0,
            dragDelta: .zero
        )

        let originalPositions = vertices.map { $0.position }
        engine.apply(at: point, to: &vertices)

        // Each vertex should move toward (0.5, 0.5, 2.0)
        for (i, v) in vertices.enumerated() {
            let orig = originalPositions[i]
            // Movement in Z should be positive (toward z=2)
            XCTAssertGreaterThan(v.position.z, orig.z,
                "Vertex \(i) should move toward z=2")
        }
    }

    /// Smooth with adjacency averages neighbor positions.
    /// Verified API — Sources/Engines/SmoothDeformer.swift:9-15
    func testSmoothDeformerWithAdjacencyAveragesNeighbors() {
        // GIVEN a mesh with known adjacency: vertex 0 neighbors {1,3}, etc.
        var mesh = makeQuadMesh()
        // Build adjacency manually to avoid relying on internal caching
        mesh.edgeAdjacentIndices = Mesh.buildEdgeAdjacency(indices: mesh.indices)

        // Build neighbor positions from adjacency
        let neighborPositions: [[SIMD3<Float>]] = mesh.edgeAdjacentIndices.map { idxs in
            idxs.map { mesh.vertices[$0].position }
        }

        // Move vertex 0 far from its neighbors so averaging is visible
        mesh.vertices[0].position = SIMD3<Float>(-2, -2, 0)

        let point = SculptPoint(
            position: SIMD3<Float>(0, 0, 0),
            normal: SIMD3<Float>(0, 0, 1),
            pressure: 1.0,
            dragDelta: .zero
        )

        // Apply smooth with adjacency to vertex 0
        let originalPosition = mesh.vertices[0].position
        let deformer = SmoothDeformer()
        deformer.deform(
            vertex: &mesh.vertices[0],
            at: point,
            radius: 5.0,
            strength: 1.0,
            falloff: 1.0,
            adjacency: neighborPositions[0]
        )

        let newPosition = mesh.vertices[0].position
        // With max strength and full falloff, vertex 0 should move toward
        // the average of its neighbors (vertices 1 and 3, at (1,0,0) and (0,1,0))
        // Average neighbor = (0.5, 0.5, 0). Vertex 0 was at (-2, -2, 0) so it should
        // move toward (0.5, 0.5, 0), meaning X and Y increase.
        // With influence = strength * falloff * pressure = 1.0 * 1.0 * 1.0 = 1.0
        // and impactDistance = sqrt((-2)^2 + (-2)^2) ≈ 2.828
        // (1 - impactDistance/radius) = 1 - 2.828/5 ≈ 0.434
        // final influence = 0.434 * 1.0 * 1.0 = 0.434
        // mix(original, avgPos, 0.434 * 1.0) → moves partially toward avg
        XCTAssertGreaterThan(newPosition.x, originalPosition.x,
            "Vertex 0 X should move toward neighbor average")
        XCTAssertGreaterThan(newPosition.y, originalPosition.y,
            "Vertex 0 Y should move toward neighbor average")
    }

    /// Verify smooth produces no NaN values.
    func testSmoothDeformerProducesNoNaN() {
        var vertices = makeQuadVertices()
        let engine = makeEngine(deformer: .smooth)

        let point = SculptPoint(
            position: SIMD3<Float>(0.5, 0.5, 0.0),
            normal: SIMD3<Float>(0, 0, 1),
            pressure: 1.0,
            dragDelta: .zero
        )

        engine.apply(at: point, to: &vertices)

        for (i, v) in vertices.enumerated() {
            XCTAssertFalse(v.position.x.isNaN, "Vertex \(i) position.x is NaN")
            XCTAssertFalse(v.position.y.isNaN, "Vertex \(i) position.y is NaN")
            XCTAssertFalse(v.position.z.isNaN, "Vertex \(i) position.z is NaN")
            XCTAssertTrue(v.position.x.isFinite, "Vertex \(i) position.x is not finite")
            XCTAssertTrue(v.position.y.isFinite, "Vertex \(i) position.y is not finite")
            XCTAssertTrue(v.position.z.isFinite, "Vertex \(i) position.z is not finite")
        }
    }

    // MARK: - Edge case: vertex outside radius is untouched

    func testVertexBeyondRadiusIsNotDeformed() {
        var vertices = makeQuadVertices()
        let engine = makeEngine(deformer: .inflate)
        engine.radius = 0.1  // tiny radius — no vertex is within 0.1 of the sculpt point

        let originalPositions = vertices.map { $0.position }

        let point = SculptPoint(
            position: SIMD3<Float>(0.5, 0.5, 5.0),  // far away from z=0 quad
            normal: SIMD3<Float>(0, 0, 1),
            pressure: 1.0,
            dragDelta: .zero
        )

        engine.apply(at: point, to: &vertices)

        for (i, v) in vertices.enumerated() {
            XCTAssertEqual(v.position.x, originalPositions[i].x, accuracy: 1e-6,
                "Vertex \(i) beyond radius should be untouched")
            XCTAssertEqual(v.position.y, originalPositions[i].y, accuracy: 1e-6,
                "Vertex \(i) beyond radius should be untouched")
            XCTAssertEqual(v.position.z, originalPositions[i].z, accuracy: 1e-6,
                "Vertex \(i) beyond radius should be untouched")
        }
    }
}
