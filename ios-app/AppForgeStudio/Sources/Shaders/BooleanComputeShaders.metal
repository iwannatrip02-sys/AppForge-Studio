// COMPUTE_SHADER: Boolean GPU compute shaders for CSG operations
#include <metal_stdlib>
using namespace metal;

// Threadgroup size: 8x8x8 = 512 threads per group
// Grid up to 128^3 = 2M voxels

// MARK: - Boolean Union

kernel void boolean_union(
    device const float* sdfA [[buffer(0)]],
    device const float* sdfB [[buffer(1)]],
    device float* output [[buffer(2)]],
    constant uint& gridSize [[buffer(3)]],
    uint3 gid [[thread_position_in_grid]]
) {
    uint idx = gid.x * gridSize * gridSize + gid.y * gridSize + gid.z;
    if (gid.x < gridSize && gid.y < gridSize && gid.z < gridSize) {
        float a = sdfA[idx];
        float b = sdfB[idx];
        output[idx] = min(a, b);
    }
}

// MARK: - Boolean Subtract (A - B)

kernel void boolean_subtract(
    device const float* sdfA [[buffer(0)]],
    device const float* sdfB [[buffer(1)]],
    device float* output [[buffer(2)]],
    constant uint& gridSize [[buffer(3)]],
    uint3 gid [[thread_position_in_grid]]
) {
    uint idx = gid.x * gridSize * gridSize + gid.y * gridSize + gid.z;
    if (gid.x < gridSize && gid.y < gridSize && gid.z < gridSize) {
        float a = sdfA[idx];
        float b = sdfB[idx];
        output[idx] = max(a, -b);
    }
}

// MARK: - Boolean Intersect

kernel void boolean_intersect(
    device const float* sdfA [[buffer(0)]],
    device const float* sdfB [[buffer(1)]],
    device float* output [[buffer(2)]],
    constant uint& gridSize [[buffer(3)]],
    uint3 gid [[thread_position_in_grid]]
) {
    uint idx = gid.x * gridSize * gridSize + gid.y * gridSize + gid.z;
    if (gid.x < gridSize && gid.y < gridSize && gid.z < gridSize) {
        float a = sdfA[idx];
        float b = sdfB[idx];
        output[idx] = max(a, b);
    }
}

// MARK: - Marching Cubes on GPU

struct VertexOut {
    float3 position;
    float3 normal;
};

kernel void marching_cubes_gpu(
    device const float* sdfGrid [[buffer(0)]],
    constant uint& gridSize [[buffer(1)]],
    constant float& voxelSize [[buffer(2)]],
    constant float3& origin [[buffer(3)]],
    device uint* cubeActive [[buffer(4)]],
    device atomic_uint* vertexCounter [[buffer(5)]],
    device VertexOut* vertices [[buffer(6)]],
    device uint* indices [[buffer(7)]],
    uint3 gid [[thread_position_in_grid]]
) {
    if (gid.x >= gridSize - 1 || gid.y >= gridSize - 1 || gid.z >= gridSize - 1) return;

    int3 offset[8] = {
        int3(0,0,0), int3(1,0,0), int3(1,1,0), int3(0,1,0),
        int3(0,0,1), int3(1,0,1), int3(1,1,1), int3(0,1,1)
    };

    int3 base = int3(gid.x, gid.y, gid.z);
    float cubeValues[8];
    for (int v = 0; v < 8; v++) {
        int3 samplePos = base + offset[v];
        uint idx = samplePos.x * int(gridSize) * int(gridSize) + samplePos.y * int(gridSize) + samplePos.z;
        cubeValues[v] = sdfGrid[idx];
    }

    int cubeIndex = 0;
    for (int v = 0; v < 8; v++) {
        if (cubeValues[v] < 0.0) cubeIndex |= (1 << v);
    }
    if (cubeIndex == 0 || cubeIndex == 255) return;

    // Mark cube as active
    uint cellIdx = gid.x * (gridSize - 1) * (gridSize - 1) + gid.y * (gridSize - 1) + gid.z;
    cubeActive[cellIdx] = cubeIndex;
}
