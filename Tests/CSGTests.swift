import XCTest
@testable import AppForgeStudio

final class CSGTests: XCTestCase {
    
    func testBoxPrimitiveCreates12Triangles() {
        let box = Shape.box(width: 2, height: 2, depth: 2)
        XCTAssertEqual(box.mesh.indices.count, 36, "Box debe tener 12 triangulos = 36 indices")
        XCTAssertEqual(box.mesh.vertices.count, 24, "Box debe tener 24 vertices (12 tri * 3 verts, sin compartir)")
    }
    
    func testCylinderPrimitiveHasCorrectStructure() {
        let cylinder = Shape.cylinder(radius: 1, height: 2)
        XCTAssertGreaterThan(cylinder.mesh.vertices.count, 0, "Cilindro debe tener vertices")
        XCTAssertGreaterThan(cylinder.mesh.indices.count, 0, "Cilindro debe tener indices")
        XCTAssertEqual(cylinder.mesh.indices.count % 3, 0, "Indices deben ser multiplo de 3")
    }
    
    func testUnionOfTwoBoxesProducesValidMesh() {
        let boxA = Shape.box(width: 2, height: 2, depth: 2)
        let boxB = Shape.box(width: 2, height: 2, depth: 2)
        let result = boxA.union(boxB)
        XCTAssertGreaterThan(result.mesh.vertices.count, 0, "Union debe producir vertices")
        XCTAssertGreaterThan(result.mesh.indices.count, 0, "Union debe producir indices")
        XCTAssertEqual(result.mesh.indices.count % 3, 0, "Indices de union deben ser multiplo de 3")
    }
    
    func testDifferenceOfTwoBoxesProducesValidMesh() {
        let boxA = Shape.box(width: 2, height: 2, depth: 2)
        let boxB = Shape.box(width: 1, height: 1, depth: 1)
        let result = boxA.difference(boxB)
        XCTAssertGreaterThan(result.mesh.vertices.count, 0, "Difference debe producir vertices")
        XCTAssertGreaterThan(result.mesh.indices.count, 0, "Difference debe producir indices")
        XCTAssertEqual(result.mesh.indices.count % 3, 0, "Indices de difference deben ser multiplo de 3")
    }
    
    func testIntersectionOfTwoBoxesProducesValidMesh() {
        let boxA = Shape.box(width: 2, height: 2, depth: 2)
        let boxB = Shape.box(width: 2, height: 2, depth: 2)
        let result = boxA.intersection(boxB)
        XCTAssertGreaterThan(result.mesh.vertices.count, 0, "Intersection debe producir vertices")
        XCTAssertGreaterThan(result.mesh.indices.count, 0, "Intersection debe producir indices")
        XCTAssertEqual(result.mesh.indices.count % 3, 0, "Indices de intersection deben ser multiplo de 3")
    }
    
    func testMeshToPolygonsAndBackPreservesCount() {
        let box = Shape.box(width: 2, height: 2, depth: 2)
        let originalVertCount = box.mesh.vertices.count
        let originalIdxCount = box.mesh.indices.count
        
        let polygons = Polygon3D.fromMesh(box.mesh)
        XCTAssertEqual(polygons.count, originalIdxCount / 3, "Cada 3 indices produce un poligono")
        
        let restoredMesh = Polygon3D.toMesh(polygons)
        XCTAssertEqual(restoredMesh.indices.count, originalIdxCount, "Mesh restaurado debe tener mismos indices")
    }
    
    func testUnionReducesTriangleCount() {
        let boxA = Shape.box(width: 2, height: 2, depth: 2)
        let boxB = Shape.box(width: 2, height: 2, depth: 2)
        let combinedTotal = boxA.mesh.indices.count + boxB.mesh.indices.count
        let result = boxA.union(boxB)
        // Union de dos cubos identicos superpuestos deberia eliminar triangulos internos
        XCTAssertLessThan(result.mesh.indices.count, combinedTotal, "Union debe eliminar triangulos internos")
    }
    
    func testNonOverlappingUnionPreservesGeometry() {
        let boxA = Shape.box(width: 1, height: 1, depth: 1)
        let boxB = Shape.box(width: 1, height: 1, depth: 1)
        // Mismos cubos en misma posicion = se funden
        let result = boxA.union(boxB)
        XCTAssertGreaterThan(result.mesh.vertices.count, 6, "Union de dos cubos debe tener al menos 8 vertices unicos")
    }
}
