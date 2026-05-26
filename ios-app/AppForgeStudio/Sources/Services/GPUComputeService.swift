import Foundation
import simd
import Metal
import OSLog

private let logger = Logger(subsystem: "com.appforgestudio", category: "GPUComputeService")

class GPUComputeService {
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private var booleanLibrary: MTLLibrary?

    init?(device: MTLDevice = MTLCreateSystemDefaultDevice()!) {
        self.device = device
        guard let queue = device.makeCommandQueue() else { return nil }
        self.commandQueue = queue
        compileBooleanShaders()
    }

    private func compileBooleanShaders() {
        let shaderSource = """
        #include <metal_stdlib>
        using namespace metal;

        kernel void boolean_union(
            device const float* sdfA [[buffer(0)]],
            device const float* sdfB [[buffer(1)]],
            device float* output [[buffer(2)]],
            constant uint& gridSize [[buffer(3)]],
            uint3 gid [[thread_position_in_grid]]
        ) {
            uint idx = gid.x * gridSize * gridSize + gid.y * gridSize + gid.z;
            if (gid.x < gridSize && gid.y < gridSize && gid.z < gridSize) {
                output[idx] = min(sdfA[idx], sdfB[idx]);
            }
        }

        kernel void boolean_subtract(
            device const float* sdfA [[buffer(0)]],
            device const float* sdfB [[buffer(1)]],
            device float* output [[buffer(2)]],
            constant uint& gridSize [[buffer(3)]],
            uint3 gid [[thread_position_in_grid]]
        ) {
            uint idx = gid.x * gridSize * gridSize + gid.y * gridSize + gid.z;
            if (gid.x < gridSize && gid.y < gridSize && gid.z < gridSize) {
                output[idx] = max(sdfA[idx], -sdfB[idx]);
            }
        }

        kernel void boolean_intersect(
            device const float* sdfA [[buffer(0)]],
            device const float* sdfB [[buffer(1)]],
            device float* output [[buffer(2)]],
            constant uint& gridSize [[buffer(3)]],
            uint3 gid [[thread_position_in_grid]]
        ) {
            uint idx = gid.x * gridSize * gridSize + gid.y * gridSize + gid.z;
            if (gid.x < gridSize && gid.y < gridSize && gid.z < gridSize) {
                output[idx] = max(sdfA[idx], sdfB[idx]);
            }
        }
        """

        do {
            booleanLibrary = try device.makeLibrary(source: shaderSource, options: nil)
            logger.info("GPUComputeService: Boolean shaders compiled successfully")
        } catch {
            logger.error("GPUComputeService: Failed to compile boolean shaders: \(error.localizedDescription)")
        }
    }

    func computeBoolean(meshA: Mesh, meshB: Mesh, operation: BooleanOp, gridSize: Int = 64) -> Mesh {
        let vertsA: [SIMD3<Float>] = meshA.vertices.map { $0.position }
        let vertsB: [SIMD3<Float>] = meshB.vertices.map { $0.position }

        let gridA = SDFEngine.voxelize(vertices: vertsA, indices: meshA.indices, gridSize: gridSize)
        let gridB = SDFEngine.voxelize(vertices: vertsB, indices: meshB.indices, gridSize: gridSize)

        guard gridA.values.count == gridB.values.count else {
            logger.error("GPUComputeService: Grid size mismatch")
            return Mesh()
        }

        let gs = gridSize
        let totalCount = gs * gs * gs
        let dataSize = MemoryLayout<Float>.stride * totalCount

        var outputValues = [Float](repeating: 0, count: totalCount)

        guard let sdfABuf = device.makeBuffer(bytes: gridA.values, length: dataSize, options: .storageModeShared),
              let sdfBBuf = device.makeBuffer(bytes: gridB.values, length: dataSize, options: .storageModeShared),
              let outputBuf = device.makeBuffer(bytes: outputValues, length: dataSize, options: .storageModeShared),
              let gridSizeBuf = device.makeBuffer(bytes: [UInt32(gs)], length: MemoryLayout<UInt32>.stride, options: .storageModeShared)
        else {
            logger.error("GPUComputeService: Failed to create buffers")
            return Mesh()
        }

        let kernelName: String
        switch operation {
        case .union: kernelName = "boolean_union"
        case .intersection: kernelName = "boolean_intersect"
        case .difference: kernelName = "boolean_subtract"
        }

        guard let library = booleanLibrary,
              let function = library.makeFunction(name: kernelName),
              let pipeline = try? device.makeComputePipelineState(function: function)
        else {
            logger.error("GPUComputeService: Failed to create pipeline for \(kernelName)")
            return Mesh()
        }

        let cmdBuffer = commandQueue.makeCommandBuffer()!
        let encoder = cmdBuffer.makeComputeCommandEncoder()!

        encoder.setComputePipelineState(pipeline)
        encoder.setBuffer(sdfABuf, offset: 0, index: 0)
        encoder.setBuffer(sdfBBuf, offset: 0, index: 1)
        encoder.setBuffer(outputBuf, offset: 0, index: 2)
        encoder.setBuffer(gridSizeBuf, offset: 0, index: 3)

        let threadsPerGroup = MTLSize(width: 8, height: 8, depth: 8)
        let grid3D = MTLSize(width: gs, height: gs, depth: gs)
        encoder.dispatchThreads(grid3D, threadsPerThreadgroup: threadsPerGroup)
        encoder.endEncoding()
        cmdBuffer.commit()
        cmdBuffer.waitUntilCompleted()

        let outputPtr = outputBuf.contents().bindMemory(to: Float.self, capacity: totalCount)
        outputValues = Array(UnsafeBufferPointer(start: outputPtr, count: totalCount))

        let resultGrid = SDFGrid(gridSize: gs, voxelSize: gridA.voxelSize, origin: gridA.origin, values: outputValues)
        let (verts, indices) = SDFEngine.reconstructMesh(from: resultGrid)

        let vertices = verts.map { Vertex(position: $0, normal: SIMD3<Float>(0, 0, 1), uv: SIMD2<Float>(0, 0)) }
        var mesh = Mesh(vertices: vertices, indices: indices)
        mesh.uploadToGPU(device: device)
        return mesh
    }
}
