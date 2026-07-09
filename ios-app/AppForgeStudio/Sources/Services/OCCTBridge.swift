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

        // El bridge nativo de OCCTSwift rellena (0,0,1) cuando la triangulación
        // no trae normales → TODAS las normales iguales → sombreado plano (los
        // objetos se ven como siluetas grises, feedback de device). Detectar
        // normales ausentes O degeneradas y calcularlas desde los triángulos.
        let degenerate: Bool = {
            guard normalCount >= vertexCount, let first = occtMesh.normals.first else { return true }
            return !occtMesh.normals.contains { simd_distance($0, first) > 0.01 }
        }()
        let normals: [SIMD3<Float>] = degenerate
            ? Self.computeVertexNormals(positions: occtMesh.vertices, indices: occtMesh.indices)
            : occtMesh.normals

        var vertices: [Vertex] = []
        for i in 0..<vertexCount {
            vertices.append(Vertex(position: occtMesh.vertices[i],
                                   normal: i < normals.count ? normals[i] : SIMD3<Float>(0, 1, 0),
                                   uv: .zero))
        }

        return Mesh(vertices: vertices, indices: occtMesh.indices)
    }

    /// Normales por vértice área-ponderadas (acumulación del cross por triángulo).
    /// OCCT triangula por cara sin compartir vértices entre caras → las aristas
    /// vivas se conservan nítidas.
    static func computeVertexNormals(positions: [SIMD3<Float>],
                                     indices: [UInt32]) -> [SIMD3<Float>] {
        var acc = [SIMD3<Float>](repeating: .zero, count: positions.count)
        var i = 0
        while i + 2 < indices.count {
            let a = Int(indices[i]), b = Int(indices[i + 1]), c = Int(indices[i + 2])
            i += 3
            guard a < positions.count, b < positions.count, c < positions.count else { continue }
            let n = simd_cross(positions[b] - positions[a], positions[c] - positions[a])
            acc[a] += n; acc[b] += n; acc[c] += n
        }
        return acc.map { simd_length($0) > 1e-9 ? simd_normalize($0) : SIMD3<Float>(0, 1, 0) }
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
