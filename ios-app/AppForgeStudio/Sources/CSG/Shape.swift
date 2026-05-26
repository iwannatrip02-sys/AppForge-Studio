import Foundation
import simd

// MARK: - Mesh y Shape: reemplazo nativo de OCCTSwift

struct Mesh {
    var vertices: [Vertex]
    var indices: [UInt32]
    
    struct Vertex {
        var position: SIMD3<Float>
        var normal: SIMD3<Float>
        var uv: SIMD2<Float>
        
        init(position: SIMD3<Float> = .zero, normal: SIMD3<Float> = [0,1,0], uv: SIMD2<Float> = .zero) {
            self.position = position
            self.normal = normal
            self.uv = uv
        }
    }
    
    init(vertices: [Vertex] = [], indices: [UInt32] = []) {
        self.vertices = vertices
        self.indices = indices
    }
}

/// Shape representa una forma 3D con operaciones CSG simplificadas
/// Implementacion nativa sin OCCT — las operaciones CSG reales se implementan con Satin/Metal en el futuro
struct Shape {
    var mesh: Mesh
    
    init(mesh: Mesh) {
        self.mesh = mesh
    }
    
    // MARK: - CSG Boolean Operations
    
    func union(_ other: Shape) -> Shape {
        let resultMesh = CSGOperation.union.apply(self.mesh, other.mesh)
        return Shape(mesh: resultMesh)
    }
    
    func difference(_ other: Shape) -> Shape {
        let resultMesh = CSGOperation.difference.apply(self.mesh, other.mesh)
        return Shape(mesh: resultMesh)
    }
    
    func intersection(_ other: Shape) -> Shape {
        let resultMesh = CSGOperation.intersection.apply(self.mesh, other.mesh)
        return Shape(mesh: resultMesh)
    }
    
    // MARK: - Primitivas
    
    static func box(width: Double, height: Double, depth: Double) -> Shape {
        let w = Float(width) * 0.5
        let h = Float(height) * 0.5
        let d = Float(depth) * 0.5
        
        let positions: [SIMD3<Float>] = [
            [-w, -h, -d], [ w, -h, -d], [ w,  h, -d], [-w,  h, -d],
            [-w, -h,  d], [ w, -h,  d], [ w,  h,  d], [-w,  h,  d]
        ]
        let indices: [UInt32] = [
            0,1,2, 0,2,3, 1,5,6, 1,6,2,
            5,4,7, 5,7,6, 4,0,3, 4,3,7,
            3,2,6, 3,6,7, 4,5,1, 4,1,0
        ]
        let vertices = positions.map { Mesh.Vertex(position: $0) }
        return Shape(mesh: Mesh(vertices: vertices, indices: indices))
    }
    
    static func cylinder(radius: Double, height: Double) -> Shape {
        let r = Float(radius)
        let h = Float(height) * 0.5
        let segments = 24
        var positions: [SIMD3<Float>] = []
        var indices: [UInt32] = []
        
        for i in 0..<segments {
            let angle = Float(i) * 2.0 * .pi / Float(segments)
            let x = r * cos(angle)
            let z = r * sin(angle)
            positions.append([x, -h, z])
            positions.append([x,  h, z])
        }
        for i in 0..<segments {
            let i0 = UInt32(i * 2)
            let i1 = UInt32(i * 2 + 1)
            let i2 = UInt32(((i + 1) % segments) * 2)
            let i3 = UInt32(((i + 1) % segments) * 2 + 1)
            indices.append(contentsOf: [i0, i1, i3, i0, i3, i2])
        }
        let vertices = positions.map { Mesh.Vertex(position: $0) }
        return Shape(mesh: Mesh(vertices: vertices, indices: indices))
    }
    
    static func sphere(radius: Double) -> Shape {
        let r = Float(radius)
        let slices = 16
        let stacks = 12
        var positions: [SIMD3<Float>] = []
        var indices: [UInt32] = []
        
        for j in 0...stacks {
            let theta = Float(j) * .pi / Float(stacks)
            for i in 0...slices {
                let phi = Float(i) * 2.0 * .pi / Float(slices)
                let x = r * sin(theta) * cos(phi)
                let y = r * cos(theta)
                let z = r * sin(theta) * sin(phi)
                positions.append([x, y, z])
            }
        }
        for j in 0..<stacks {
            for i in 0..<slices {
                let i0 = UInt32(j * (slices + 1) + i)
                let i1 = UInt32(j * (slices + 1) + i + 1)
                let i2 = UInt32((j + 1) * (slices + 1) + i)
                let i3 = UInt32((j + 1) * (slices + 1) + i + 1)
                indices.append(contentsOf: [i0, i1, i2, i1, i3, i2])
            }
        }
        let vertices = positions.map { Mesh.Vertex(position: $0) }
        return Shape(mesh: Mesh(vertices: vertices, indices: indices))
    }
    
    static func torus(majorRadius: Double, minorRadius: Double) -> Shape {
        let R = Float(majorRadius)
        let r = Float(minorRadius)
        let segments = 24
        let sides = 12
        var positions: [SIMD3<Float>] = []
        var indices: [UInt32] = []
        
        for i in 0..<segments {
            let u = Float(i) * 2.0 * .pi / Float(segments)
            for j in 0..<sides {
                let v = Float(j) * 2.0 * .pi / Float(sides)
                let x = (R + r * cos(v)) * cos(u)
                let y = r * sin(v)
                let z = (R + r * cos(v)) * sin(u)
                positions.append([x, y, z])
            }
        }
        for i in 0..<segments {
            for j in 0..<sides {
                let i0 = UInt32(i * sides + j)
                let i1 = UInt32(i * sides + (j + 1) % sides)
                let i2 = UInt32(((i + 1) % segments) * sides + j)
                let i3 = UInt32(((i + 1) % segments) * sides + (j + 1) % sides)
                indices.append(contentsOf: [i0, i1, i2, i1, i3, i2])
            }
        }
        let vertices = positions.map { Mesh.Vertex(position: $0) }
        return Shape(mesh: Mesh(vertices: vertices, indices: indices))
    }
    
    static func cone(radius: Double, height: Double) -> Shape {
        let r = Float(radius)
        let h = Float(height)
        let segments = 24
        var positions: [SIMD3<Float>] = [[0, -h/2, 0], [0, h/2, 0]]
        var indices: [UInt32] = []
        
        for i in 0..<segments {
            let angle = Float(i) * 2.0 * .pi / Float(segments)
            positions.append([r * cos(angle), -h/2, r * sin(angle)])
        }
        for i in 0..<segments {
            let a = UInt32(i + 2)
            let b = UInt32(((i + 1) % segments) + 2)
            indices.append(contentsOf: [0, a, b, 1, b, a])
        }
        let vertices = positions.map { Mesh.Vertex(position: $0) }
        return Shape(mesh: Mesh(vertices: vertices, indices: indices))
    }
    
    static func face(p0: SIMD3<Double>, p1: SIMD3<Double>, p2: SIMD3<Double>) throws -> Shape {
        let verts = [
            Mesh.Vertex(position: [Float(p0.x), Float(p0.y), Float(p0.z)]),
            Mesh.Vertex(position: [Float(p1.x), Float(p1.y), Float(p1.z)]),
            Mesh.Vertex(position: [Float(p2.x), Float(p2.y), Float(p2.z)])
        ]
        return Shape(mesh: Mesh(vertices: verts, indices: [0, 1, 2]))
    }
    
    static func shell(faces: [Shape]) -> Shape {
        var allVerts: [Mesh.Vertex] = []
        var allIndices: [UInt32] = []
        var offset: UInt32 = 0
        for face in faces {
            allVerts.append(contentsOf: face.mesh.vertices)
            allIndices.append(contentsOf: face.mesh.indices.map { $0 + offset })
            offset += UInt32(face.mesh.vertices.count)
        }
        return Shape(mesh: Mesh(vertices: allVerts, indices: allIndices))
    }
    
    static func solid(shell: Shape) -> Shape {
        return shell
    }
    
    // MARK: - CSG Operations (simplificadas)
    
    static func + (a: Shape, b: Shape) -> Shape {
        var verts = a.mesh.vertices
        var idxs = a.mesh.indices
        let offset = UInt32(verts.count)
        verts.append(contentsOf: b.mesh.vertices)
        idxs.append(contentsOf: b.mesh.indices.map { $0 + offset })
        return Shape(mesh: Mesh(vertices: verts, indices: idxs))
    }
    
    static func - (a: Shape, b: Shape) -> Shape {
        return a
    }
    
    static func & (a: Shape, b: Shape) -> Shape {
        return a
    }
    
    func filleted(radius: Double) -> Shape { return self }
    func chamfered(radius: Double) -> Shape { return self }
    func shelled(thickness: Double) -> Shape { return self }
    func extruded(direction: (dx: Double, dy: Double, dz: Double), distance: Double) -> Shape { return self }
    func revolved(angle: Double) -> Shape { return self }
    func swept(along pathPoints: [SIMD3<Double>]) -> Shape { return self }
}
