import Foundation
import simd
import OSLog

private let logger = Logger(subsystem: "com.appforgestudio", category: "ShellEngine")

class ShellEngine {

    func computeShell(faceIndex: Int, thickness: Float, mesh: inout Mesh) -> Bool {
        guard thickness > 0, mesh.vertices.count >= 4 else { return false }
        let vertCount = mesh.vertices.count

        guard faceIndex * 3 + 2 < mesh.indices.count else {
            logger.error("ShellEngine: faceIndex \(faceIndex) out of range")
            return false
        }

        let refStart = faceIndex * 3
        let ri0 = Int(mesh.indices[refStart])
        let ri1 = Int(mesh.indices[refStart + 1])
        let ri2 = Int(mesh.indices[refStart + 2])
        let refNormal = normalize(cross(
            mesh.vertices[ri1].position - mesh.vertices[ri0].position,
            mesh.vertices[ri2].position - mesh.vertices[ri0].position
        ))

        var faceTriangles = Set<Int>()
        var faceVertices = Set<Int>()

        for i in stride(from: 0, to: mesh.indices.count, by: 3) {
            let i0 = Int(mesh.indices[i])
            let i1 = Int(mesh.indices[i+1])
            let i2 = Int(mesh.indices[i+2])
            let triN = normalize(cross(
                mesh.vertices[i1].position - mesh.vertices[i0].position,
                mesh.vertices[i2].position - mesh.vertices[i0].position
            ))
            if dot(triN, refNormal) > 0.9 {
                faceTriangles.insert(i)
                faceVertices.insert(i0)
                faceVertices.insert(i1)
                faceVertices.insert(i2)
            }
        }

        guard !faceTriangles.isEmpty else {
            logger.warning("ShellEngine: no coplanar triangles found for face \(faceIndex)")
            return false
        }

        var vertNormals = [SIMD3<Float>](repeating: .zero, count: vertCount)
        for tri in faceTriangles {
            let i0 = Int(mesh.indices[tri])
            let i1 = Int(mesh.indices[tri + 1])
            let i2 = Int(mesh.indices[tri + 2])
            let tn = normalize(cross(
                mesh.vertices[i1].position - mesh.vertices[i0].position,
                mesh.vertices[i2].position - mesh.vertices[i0].position
            ))
            vertNormals[i0] += tn
            vertNormals[i1] += tn
            vertNormals[i2] += tn
        }

        for i in faceVertices where length(vertNormals[i]) > 1e-6 {
            vertNormals[i] = normalize(vertNormals[i])
        }

        var newVertices = mesh.vertices
        var newIndices = [UInt32]()

        var innerMap = [Int: Int]()
        for idx in faceVertices {
            let offset = mesh.vertices[idx].position - vertNormals[idx] * thickness
            innerMap[idx] = newVertices.count
            newVertices.append(Vertex(position: offset, normal: -vertNormals[idx], uv: mesh.vertices[idx].uv))
        }

        for i in stride(from: 0, to: mesh.indices.count, by: 3) {
            guard !faceTriangles.contains(i) else { continue }
            newIndices.append(contentsOf: [mesh.indices[i], mesh.indices[i+1], mesh.indices[i+2]])
        }

        for tri in faceTriangles {
            let i0 = Int(mesh.indices[tri])
            let i1 = Int(mesh.indices[tri + 1])
            let i2 = Int(mesh.indices[tri + 2])
            guard let ni0 = innerMap[i0],
                  let ni1 = innerMap[i1],
                  let ni2 = innerMap[i2] else { continue }
            newIndices.append(contentsOf: [UInt32(ni0), UInt32(ni2), UInt32(ni1)])
        }

        var edgeCount = [Int: Int]()
        var edgePairs = [Int: (Int, Int)]()
        for tri in faceTriangles {
            let i0 = Int(mesh.indices[tri])
            let i1 = Int(mesh.indices[tri + 1])
            let i2 = Int(mesh.indices[tri + 2])
            let triEdges = [(i0, i1), (i1, i2), (i2, i0)]
            for (ea, eb) in triEdges {
                let ek = min(ea, eb) * max(vertCount, 1) + max(ea, eb)
                edgeCount[ek, default: 0] += 1
                edgePairs[ek] = (ea, eb)
            }
        }

        for (ek, cnt) in edgeCount where cnt == 1 {
            guard let (ea, eb) = edgePairs[ek],
                  let innerA = innerMap[ea],
                  let innerB = innerMap[eb] else { continue }
            newIndices.append(contentsOf: [UInt32(ea), UInt32(eb), UInt32(innerB)])
            newIndices.append(contentsOf: [UInt32(ea), UInt32(innerB), UInt32(innerA)])
        }

        mesh = Mesh(vertices: newVertices, indices: newIndices)
        return true
    }
}
