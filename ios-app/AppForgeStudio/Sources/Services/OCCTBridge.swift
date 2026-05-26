import Foundation
import simd
import OCCTSwift

/// Bridges OCCTSwift B-rep shapes (from gsdali/OCCTSwift) to AppForge Studio's Mesh type for Metal rendering.
/// All OCCTSwift operations return Shape? — operations can fail on degenerate geometry.
enum OCCTBridge {
    
    /// Triangulate an OCCTSwift B-rep shape into our Mesh type.
    /// OCCTSwift.mesh() returns [SIMD3<Float>] vertices, [SIMD3<Float>] normals, [UInt32] indices.
    static func shapeToMesh(_ shape: OCCTSwift.Shape,
                            linearDeflection: Double = 0.1,
                            angularDeflection: Double = 0.5) -> Mesh? {
        guard let occtMesh = shape.mesh(linearDeflection: linearDeflection,
                                         angularDeflection: angularDeflection) else {
            return nil
        }
        
        let vertexCount = occtMesh.vertices.count
        let normalCount = occtMesh.normals.count
        
        var vertices: [Vertex] = []
        for i in 0..<vertexCount {
            let pos = occtMesh.vertices[i]
            let nrm = normalCount > i ? occtMesh.normals[i] : SIMD3<Float>(0, 1, 0)
            vertices.append(Vertex(position: pos, normal: nrm, uv: .zero))
        }
        
        return Mesh(vertices: vertices, indices: occtMesh.indices)
    }
    
    static func toMesh(_ shape: OCCTSwift.Shape, quality: MeshQuality = .medium) -> Mesh? {
        let deflection: Double
        switch quality {
        case .low:     deflection = 0.5
        case .medium:  deflection = 0.1
        case .high:    deflection = 0.02
        case .ultra:   deflection = 0.005
        }
        return shapeToMesh(shape, linearDeflection: deflection)
    }
    
    /// Require mesh (fatal on nil) for cases where we know the shape is valid.
    static func toMeshRequired(_ shape: OCCTSwift.Shape, quality: MeshQuality = .medium) -> Mesh {
        toMesh(shape, quality: quality) ?? Mesh(vertices: [], indices: [])
    }
}

enum MeshQuality: String, CaseIterable {
    case low, medium, high, ultra
}

// MARK: - OCCTSwift.Shape convenience extensions for AppForge

extension OCCTSwift.Shape {
    
    /// Fallback mesh with default quality
    func appforgeMesh(quality: MeshQuality = .medium) -> Mesh {
        OCCTBridge.toMesh(self, quality: quality) ?? Mesh(vertices: [], indices: [])
    }
    
    /// Safe union that handles optional result
    func safeUnion(_ other: OCCTSwift.Shape) -> OCCTSwift.Shape {
        (self + other) ?? self
    }
    
    /// Safe subtract that handles optional result
    func safeSubtract(_ other: OCCTSwift.Shape) -> OCCTSwift.Shape {
        (self - other) ?? self
    }
    
    /// Safe intersect that handles optional result
    func safeIntersect(_ other: OCCTSwift.Shape) -> OCCTSwift.Shape {
        (self & other) ?? self
    }
    
    /// Safe fillet
    func safeFillet(radius: Double) -> OCCTSwift.Shape {
        filleted(radius: radius) ?? self
    }
    
    /// Safe chamfer
    func safeChamfer(distance: Double) -> OCCTSwift.Shape {
        chamfered(distance: distance) ?? self
    }
    
    /// Safe shell (negative = inward)
    func safeShell(thickness: Double) -> OCCTSwift.Shape {
        shelled(thickness: thickness) ?? self
    }
}
