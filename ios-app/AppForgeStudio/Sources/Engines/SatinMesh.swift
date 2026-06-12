import Foundation
import Metal
import Satin
import simd
import OSLog

private let logger = Logger(subsystem: "com.appforgestudio", category: "SatinMesh")
class SatinMesh: Satin.Mesh {
    var vertexBuffer: MTLBuffer?
    var indexBuffer: MTLBuffer?
    var vertexCount: Int = 0
    var indexCount: Int = 0
    var meshColor: simd_float4 = simd_float4(0.5, 0.5, 0.5, 1.0)

    init(device: MTLDevice, vertices: [Float] = [], indices: [UInt16] = [], color: simd_float4 = simd_float4(0.5, 0.5, 0.5, 1.0)) {
        let geometry = Geometry()
        let vertexData = !vertices.isEmpty ? vertices : [0,0,0, 0,0,1, 1,0,0, 1,0,1]
        var indexData = !indices.isEmpty ? indices : [0,1,2, 2,1,3]

        // Build position attribute from flat [Float] → [simd_float3]
        // Evidence: vendor/Satin/Sources/Satin/Geometry/Utilities/BufferAttribute.swift:376 — Float3BufferAttribute exists
        // Evidence: vendor/Satin/Sources/Satin/Constants/Pipelines/VertexConstants.swift:53 — VertexAttributeIndex.Position
        // Evidence: vendor/Satin/Sources/Satin/Core/Geometry.swift:185 — geometry.addAttribute(_:for:)
        let positionCount = vertexData.count / 3
        var positions: [simd_float3] = []
        positions.reserveCapacity(positionCount)
        for i in 0..<positionCount {
            let base = i * 3
            positions.append(simd_float3(vertexData[base], vertexData[base+1], vertexData[base+2]))
        }
        let attr = Float3BufferAttribute(defaultValue: .zero, data: positions, stepRate: 1, stepFunction: .perVertex)
        geometry.addAttribute(attr, for: .Position)

        // Set up index element buffer
        // Evidence: vendor/Satin/Sources/Satin/Geometry/Utilities/ElementBuffer.swift:34 — ElementBuffer(type:data:count:source:)
        // Evidence: vendor/Satin/Sources/Satin/Core/Geometry.swift:168 — geometry.setElements(_:)
        if !indexData.isEmpty {
            geometry.setElements(ElementBuffer(type: .uint16, data: &indexData, count: indexData.count, source: indexData))
        }

        // Evidence: vendor/Satin/Sources/Satin/Materials/BasicColorMaterial.swift:22 — BasicColorMaterial(color:blending:)
        let material = BasicColorMaterial(color: color)
        // Evidence: vendor/Satin/Sources/Satin/Core/Mesh.swift:152 — Mesh(geometry:material:) exists on Mesh
        super.init(geometry: geometry, material: material)
        self.meshColor = color
        if !vertices.isEmpty {
            vertexBuffer = device.makeBuffer(bytes: vertices, length: vertices.count * MemoryLayout<Float>.size, options: [])
            vertexCount = vertices.count / 13
            if !indices.isEmpty {
                indexBuffer = device.makeBuffer(bytes: indices, length: indices.count * MemoryLayout<UInt16>.size, options: [])
                indexCount = indices.count
            }
        }
    }

    required init(from decoder: Decoder) throws {
        try super.init(from: decoder)
    }

    func updateColor(_ color: simd_float4) {
        meshColor = color
        material?.set("ModelColor", color)
    }
}
