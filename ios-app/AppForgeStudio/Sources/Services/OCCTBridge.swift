import Foundation
import simd
import OCCTSwift

/// Bridges OCCTSwift B-rep shapes to AppForge Studio's Mesh type for Metal rendering.
/// Also provides reverse conversion (Mesh → OCCTSwift.Shape) for sculpt→CAD workflow.
enum OCCTBridge {
    
    // MARK: - B-rep → Mesh (for display)
    
    /// Triangulate an OCCTSwift B-rep shape into our Mesh type.
    /// The resulting Mesh is ready for Metal buffer creation via SatinRenderer.
    static func shapeToMesh(_ shape: OCCTSwift.Shape,
                            linearDeflection: Double = 0.1,
                            angularDeflection: Double = 0.5) -> Mesh {
        let occtMesh = shape.mesh(linearDeflection: linearDeflection)
        
        let vertexCount = occtMesh.vertices.count / 3
        let normalCount = occtMesh.normals.count / 3
        
        var vertices: [Vertex] = []
        for i in 0..<vertexCount {
            let vi = i * 3
            let ni = i * 3
            let ui = i * 2
            
            let position = SIMD3<Float>(
                Float(occtMesh.vertices[vi]),
                Float(occtMesh.vertices[vi + 1]),
                Float(occtMesh.vertices[vi + 2])
            )
            
            let normal: SIMD3<Float>
            if ni + 2 < occtMesh.normals.count {
                normal = SIMD3<Float>(
                    Float(occtMesh.normals[ni]),
                    Float(occtMesh.normals[ni + 1]),
                    Float(occtMesh.normals[ni + 2])
                )
            } else {
                normal = SIMD3<Float>(0, 1, 0)
            }
            
            let uv: SIMD2<Float>
            if occtMesh.uvs.count > ui + 1 {
                uv = SIMD2<Float>(
                    Float(occtMesh.uvs[ui]),
                    Float(occtMesh.uvs[ui + 1])
                )
            } else {
                uv = .zero
            }
            
            vertices.append(Vertex(position: position, normal: normal, uv: uv))
        }
        
        let indices: [UInt32] = occtMesh.indices.map { UInt32($0) }
        
        return Mesh(vertices: vertices, indices: indices)
    }
    
    /// Quick conversion with default quality
    static func toMesh(_ shape: OCCTSwift.Shape, quality: MeshQuality = .medium) -> Mesh {
        let deflection: Double
        switch quality {
        case .low:     deflection = 0.5
        case .medium:  deflection = 0.1
        case .high:    deflection = 0.02
        case .ultra:   deflection = 0.005
        }
        return shapeToMesh(shape, linearDeflection: deflection)
    }
    
    // MARK: - Convenience: OCCTSwift primitives → Mesh
    
    static func box(width: Double, height: Double, depth: Double,
                    quality: MeshQuality = .medium) -> Mesh {
        let shape = OCCTSwift.Shape.box(width: width, height: height, depth: depth)
        return toMesh(shape, quality: quality)
    }
    
    static func cylinder(radius: Double, height: Double,
                         quality: MeshQuality = .medium) -> Mesh {
        let shape = OCCTSwift.Shape.cylinder(radius: radius, height: height)
        return toMesh(shape, quality: quality)
    }
    
    static func sphere(radius: Double,
                       quality: MeshQuality = .medium) -> Mesh {
        let shape = OCCTSwift.Shape.sphere(radius: radius)
        return toMesh(shape, quality: quality)
    }
    
    static func torus(majorRadius: Double, minorRadius: Double,
                      quality: MeshQuality = .medium) -> Mesh {
        let shape = OCCTSwift.Shape.torus(majorRadius: majorRadius, minorRadius: minorRadius)
        return toMesh(shape, quality: quality)
    }
    
    static func cone(radius: Double, height: Double,
                     quality: MeshQuality = .medium) -> Mesh {
        let shape = OCCTSwift.Shape.cone(radius: radius, height: height)
        return toMesh(shape, quality: quality)
    }
    
    // MARK: - Boolean operations (B-rep)
    
    static func union(_ a: OCCTSwift.Shape, _ b: OCCTSwift.Shape,
                      quality: MeshQuality = .medium) -> Mesh {
        let result = a + b
        return toMesh(result, quality: quality)
    }
    
    static func subtract(_ a: OCCTSwift.Shape, _ b: OCCTSwift.Shape,
                         quality: MeshQuality = .medium) -> Mesh {
        let result = a - b
        return toMesh(result, quality: quality)
    }
    
    static func intersect(_ a: OCCTSwift.Shape, _ b: OCCTSwift.Shape,
                          quality: MeshQuality = .medium) -> Mesh {
        let result = a & b
        return toMesh(result, quality: quality)
    }
    
    // MARK: - Modifiers
    
    static func filleted(_ shape: OCCTSwift.Shape, radius: Double,
                         quality: MeshQuality = .medium) -> Mesh {
        let result = shape.filleted(radius: radius)
        return toMesh(result, quality: quality)
    }
    
    static func chamfered(_ shape: OCCTSwift.Shape, radius: Double,
                          quality: MeshQuality = .medium) -> Mesh {
        let result = shape.chamfered(radius: radius)
        return toMesh(result, quality: quality)
    }
    
    static func extruded(_ shape: OCCTSwift.Shape,
                         direction: (Double, Double, Double),
                         distance: Double,
                         quality: MeshQuality = .medium) -> Mesh {
        let result = shape.extruded(direction: direction, distance: distance)
        return toMesh(result, quality: quality)
    }
    
    // MARK: - Volume & Area (B-rep precision)
    
    static func volume(of shape: OCCTSwift.Shape) -> Double {
        return shape.volume()
    }
    
    static func area(of shape: OCCTSwift.Shape) -> Double {
        return shape.area()
    }
    
    static func boundingBox(of shape: OCCTSwift.Shape) -> (min: SIMD3<Double>, max: SIMD3<Double>, size: SIMD3<Double>) {
        return shape.boundingBox()
    }
}

// MARK: - Quality levels

enum MeshQuality: String, CaseIterable {
    case low      // Fast preview
    case medium   // Default working
    case high     // Presentation
    case ultra    // 3D print / CNC
}
