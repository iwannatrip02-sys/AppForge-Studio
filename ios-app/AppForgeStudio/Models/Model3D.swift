import Combine
import Satin
import Foundation
import Metal
import simd

class Model: ObservableObject {
    let id: UUID
    @Published var name: String
    @Published var vertexBuffer: MTLBuffer?
    @Published var indexBuffer: MTLBuffer?
    @Published var vertexCount: Int
    @Published var indexCount: Int
    @Published var meshes: [Mesh] = []
    @Published var color: SIMD4<Float>
    @Published var cadHistoryID: UUID?
    @Published var originOp: String?

    @Published var position: SIMD3<Float>
    @Published var rotation: simd_quatf
    @Published var scale: SIMD3<Float>

    var transform: simd_float4x4 {
        get {
            let T = simd_float4x4(
                SIMD4<Float>(1, 0, 0, 0),
                SIMD4<Float>(0, 1, 0, 0),
                SIMD4<Float>(0, 0, 1, 0),
                SIMD4<Float>(position.x, position.y, position.z, 1)
            )
            let R = simd_float4x4(rotation)
            let S = simd_float4x4(
                SIMD4<Float>(scale.x, 0, 0, 0),
                SIMD4<Float>(0, scale.y, 0, 0),
                SIMD4<Float>(0, 0, scale.z, 0),
                SIMD4<Float>(0, 0, 0, 1)
            )
            return T * R * S
        }
        set {
            updateTransform(newValue)
        }
    }

    init(name: String = "Model", vertices: [Float] = [], indices: [UInt16] = [], device: MTLDevice? = nil) {
        self.id = UUID()
        self.name = name
        self.vertexCount = vertices.count / 13
        self.indexCount = indices.count
        self.position = .zero
        self.rotation = simd_quatf(real: 1, imag: .zero)
        self.scale = SIMD3<Float>(1, 1, 1)
        self.color = SIMD4<Float>(0.7, 0.7, 0.7, 1.0)

        if let device = device, !vertices.isEmpty {
            setBuffers(vertices: vertices, indices: indices, device: device)
        }
    }

    func setBuffers(vertices: [Float], indices: [UInt16], device: MTLDevice) {
        vertexBuffer = device.makeBuffer(bytes: vertices, length: vertices.count * MemoryLayout<Float>.stride, options: .storageModeShared)
        indexBuffer = device.makeBuffer(bytes: indices, length: indices.count * MemoryLayout<UInt16>.stride, options: .storageModeShared)
        vertexCount = vertices.count / 13
        indexCount = indices.count
    }

    func updateTransform(_ newTransform: simd_float4x4) {
        position = SIMD3<Float>(newTransform.columns.3.x, newTransform.columns.3.y, newTransform.columns.3.z)
        let sx = simd_length(SIMD3<Float>(newTransform.columns.0.x, newTransform.columns.0.y, newTransform.columns.0.z))
        let sy = simd_length(SIMD3<Float>(newTransform.columns.1.x, newTransform.columns.1.y, newTransform.columns.1.z))
        let sz = simd_length(SIMD3<Float>(newTransform.columns.2.x, newTransform.columns.2.y, newTransform.columns.2.z))
        scale = SIMD3<Float>(sx, sy, sz)
        let rotMatrix = simd_float3x3(
            SIMD3<Float>(newTransform.columns.0.x / sx, newTransform.columns.0.y / sy, newTransform.columns.0.z / sz),
            SIMD3<Float>(newTransform.columns.1.x / sx, newTransform.columns.1.y / sy, newTransform.columns.1.z / sz),
            SIMD3<Float>(newTransform.columns.2.x / sx, newTransform.columns.2.y / sy, newTransform.columns.2.z / sz)
        )
        rotation = simd_quatf(rotMatrix)
    }
}
