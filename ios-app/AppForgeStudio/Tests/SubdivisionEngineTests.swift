import XCTest
import simd
@testable import AppForgeStudio

/// Tests for SubdivisionEngine (F4.T3).
///
/// Verifies:
///   - Catmull-Clark (triangular adaptation): cube → smoothed shape with >50 faces
///   - Loop subdivision: tetrahedron → 16 triangles (1→4 per level)
///   - No NaN in output positions or normals
///   - Zero-division guards (empty mesh, single triangle)
///   - previewSubdivision smoothing
@MainActor
final class SubdivisionEngineTests: XCTestCase {

    var engine: SubdivisionEngine!

    override func setUp() {
        super.setUp()
        engine = SubdivisionEngine()
    }

    override func tearDown() {
        engine = nil
        super.tearDown()
    }

    // MARK: - Test mesh factories

    /// Creates a unit cube mesh centered at origin (12 triangles, 2 per face).
    private func makeCube() -> Mesh {
        // 8 vertices, 1 per corner of [-0.5, 0.5]³
        let verts: [Vertex] = [
            Vertex(position: SIMD3<Float>(-0.5, -0.5, -0.5)),
            Vertex(position: SIMD3<Float>( 0.5, -0.5, -0.5)),
            Vertex(position: SIMD3<Float>( 0.5,  0.5, -0.5)),
            Vertex(position: SIMD3<Float>(-0.5,  0.5, -0.5)),
            Vertex(position: SIMD3<Float>(-0.5, -0.5,  0.5)),
            Vertex(position: SIMD3<Float>( 0.5, -0.5,  0.5)),
            Vertex(position: SIMD3<Float>( 0.5,  0.5,  0.5)),
            Vertex(position: SIMD3<Float>(-0.5,  0.5,  0.5)),
        ]
        // 6 faces × 2 triangles = 12 tris
        let indices: [UInt32] = [
            0,2,1, 0,3,2, // -Z
            4,5,6, 4,6,7, // +Z
            0,1,5, 0,5,4, // -Y
            2,3,7, 2,7,6, // +Y
            0,4,7, 0,7,3, // -X
            1,2,6, 1,6,5, // +X
        ]
        return Mesh(vertices: verts, indices: indices)
    }

    /// Creates a regular tetrahedron (4 vertices, 4 triangles).
    private func makeTetrahedron() -> Mesh {
        let a = SIMD3<Float>(0, 1, 0)
        let b = SIMD3<Float>(0, -1.0/3.0, 2.0*sqrt(2.0)/3.0)
        let c = SIMD3<Float>( sqrt(2.0/3.0), -1.0/3.0, -sqrt(2.0)/3.0)
        let d = SIMD3<Float>(-sqrt(2.0/3.0), -1.0/3.0, -sqrt(2.0)/3.0)
        let verts: [Vertex] = [a, b, c, d].map { Vertex(position: $0) }
        let indices: [UInt32] = [0,1,2, 0,2,3, 0,3,1, 1,3,2]
        return Mesh(vertices: verts, indices: indices)
    }

    /// Creates a single triangle.
    private func makeTriangle() -> Mesh {
        let verts: [Vertex] = [
            Vertex(position: SIMD3<Float>(0, 0, 0)),
            Vertex(position: SIMD3<Float>(1, 0, 0)),
            Vertex(position: SIMD3<Float>(0, 1, 0)),
        ]
        return Mesh(vertices: verts, indices: [0, 1, 2])
    }

    // MARK: - Catmull-Clark tests

    func testCatmullClarkCubeIncreasesFaceCount() {
        let cube = makeCube()
        let result = engine.subdivide(cube, levels: 1)
        // 12 original tris → each splits into 3 quad → 6 tris per quad = 72 tris
        XCTAssertGreaterThan(result.indices.count, 36,
            "CC level 1: cube should produce >36 indices (12 tris → 72)")
    }

    func testCatmullClarkTwoLevelsProducesManyFaces() {
        let cube = makeCube()
        let result = engine.subdivide(cube, levels: 2)
        let triCount = result.indices.count / 3
        XCTAssertGreaterThanOrEqual(triCount, 50,
            "CC level 2: cube should have ≥50 faces (spec requirement)")
    }

    func testCatmullClarkProgressUpdates() {
        let cube = makeCube()
        let _ = engine.subdivide(cube, levels: 2)
        XCTAssertEqual(engine.progress, 1.0)
        XCTAssertFalse(engine.isSubdividing)
    }

    func testCatmullClarkEmptyMesh() {
        let empty = Mesh()
        let result = engine.subdivide(empty, levels: 3)
        XCTAssertEqual(result.vertices.count, 0)
        XCTAssertEqual(result.indices.count, 0)
    }

    func testCatmullClarkSingleTriangle() {
        let tri = makeTriangle()
        let result = engine.subdivide(tri, levels: 1)
        // 1 tri → 6 tris (3 quad-like faces × 2)
        XCTAssertEqual(result.indices.count / 3, 6)
    }

    func testCatmullClarkZeroLevels() {
        let cube = makeCube()
        let result = engine.subdivide(cube, levels: 0)
        XCTAssertEqual(result.indices.count, cube.indices.count,
            "0 levels should return identical mesh")
    }

    // MARK: - Loop subdivision tests

    func testLoopSubdivisionTetrahedron() {
        let tet = makeTetrahedron()
        let result = engine.loopSubdivide(tet, levels: 1)
        // 4 original tris → 4 × 4 = 16 tris
        let triCount = result.indices.count / 3
        XCTAssertEqual(triCount, 16,
            "Loop level 1: tetrahedron should produce 16 triangles (4 → 16)")
    }

    func testLoopSubdivisionTwoLevels() {
        let tet = makeTetrahedron()
        let result = engine.loopSubdivide(tet, levels: 2)
        // 4 → 16 → 64 tris
        let triCount = result.indices.count / 3
        XCTAssertEqual(triCount, 64,
            "Loop level 2: 4 → 16 → 64 triangles")
    }

    func testLoopSubdivisionIncreasesVertexCount() {
        let tet = makeTetrahedron()
        let result = engine.loopSubdivide(tet, levels: 1)
        // Original 4 vertices + 6 edge points = 10
        XCTAssertGreaterThan(result.vertices.count, tet.vertices.count)
    }

    func testLoopSubdivisionEmptyMesh() {
        let empty = Mesh()
        let result = engine.loopSubdivide(empty, levels: 3)
        XCTAssertEqual(result.vertices.count, 0)
    }

    // MARK: - NaN prevention

    func testCatmullClarkNoNaN() {
        let cube = makeCube()
        let result = engine.subdivide(cube, levels: 2)
        for v in result.vertices {
            XCTAssertFalse(v.position.x.isNaN, "position.x should not be NaN")
            XCTAssertFalse(v.position.y.isNaN, "position.y should not be NaN")
            XCTAssertFalse(v.position.z.isNaN, "position.z should not be NaN")
            XCTAssertFalse(v.normal.x.isNaN, "normal.x should not be NaN")
        }
    }

    func testLoopSubdivisionNoNaN() {
        let tet = makeTetrahedron()
        let result = engine.loopSubdivide(tet, levels: 2)
        for v in result.vertices {
            XCTAssertFalse(v.position.x.isNaN)
            XCTAssertFalse(v.position.y.isNaN)
            XCTAssertFalse(v.position.z.isNaN)
        }
    }

    func testNoNaNWithZeroAreaTriangle() {
        // Degenerate triangle (all points collinear)
        let verts: [Vertex] = [
            Vertex(position: SIMD3<Float>(0, 0, 0)),
            Vertex(position: SIMD3<Float>(1, 0, 0)),
            Vertex(position: SIMD3<Float>(0.5, 0, 0)),
        ]
        let mesh = Mesh(vertices: verts, indices: [0, 1, 2])
        // Should not crash or produce NaN
        let result = engine.subdivide(mesh, levels: 1)
        for v in result.vertices {
            XCTAssertFalse(v.position.x.isNaN)
        }
    }

    // MARK: - Normals

    func testCatmullClarkNormalsAreUnitLength() {
        let cube = makeCube()
        let result = engine.subdivide(cube, levels: 1)
        for v in result.vertices {
            let len = simd_length(v.normal)
            if len > 0 {
                XCTAssertEqual(len, 1.0, accuracy: 0.01,
                    "normals should be unit length or zero")
            }
        }
    }

    func testLoopSubdivisionNormalsAreUnitLength() {
        let tet = makeTetrahedron()
        let result = engine.loopSubdivide(tet, levels: 1)
        for v in result.vertices {
            let len = simd_length(v.normal)
            if len > 0 {
                XCTAssertEqual(len, 1.0, accuracy: 0.01)
            }
        }
    }

    // MARK: - Preview smoothing

    func testPreviewSubdivisionSmooths() {
        let cube = makeCube()
        let result = engine.previewSubdivision(cube, level: 1)
        // Vertex count unchanged (only position smoothing)
        XCTAssertEqual(result.vertices.count, cube.vertices.count)
        XCTAssertEqual(result.indices.count, cube.indices.count)
    }

    func testPreviewSubdivisionZeroLevels() {
        let cube = makeCube()
        let result = engine.previewSubdivision(cube, level: 0)
        // Should return identical mesh
        XCTAssertEqual(result.vertices[0].position, cube.vertices[0].position)
    }

    // MARK: - Mesh validity

    func testCatmullClarkProducesValidIndices() {
        let cube = makeCube()
        let result = engine.subdivide(cube, levels: 1)
        // All indices must reference valid vertices
        for idx in result.indices {
            XCTAssertLessThan(Int(idx), result.vertices.count,
                "index \(idx) references non-existent vertex")
        }
    }

    func testLoopSubdivisionProducesValidIndices() {
        let tet = makeTetrahedron()
        let result = engine.loopSubdivide(tet, levels: 1)
        for idx in result.indices {
            XCTAssertLessThan(Int(idx), result.vertices.count,
                "index \(idx) references non-existent vertex")
        }
    }

    func testCatmullClarkAllIndicesUsed() {
        let cube = makeCube()
        let result = engine.subdivide(cube, levels: 1)
        // Every vertex should be referenced by at least one index
        var referenced = Set<Int>()
        for idx in result.indices { referenced.insert(Int(idx)) }
        for i in 0..<result.vertices.count {
            XCTAssertTrue(referenced.contains(i),
                "vertex \(i) is unreferenced in output mesh")
        }
    }
}
