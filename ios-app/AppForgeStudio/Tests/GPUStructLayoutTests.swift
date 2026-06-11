import XCTest
import simd
@testable import AppForgeStudio

/// Regression tests for GPU struct memory layout (BUG1, BUG3).
///
/// Verifies Swift struct layouts match Metal shader expectations byte-for-byte.
/// Mismatches cause silent rendering corruption (wrong colors, broken normals).
final class GPUStructLayoutTests: XCTestCase {

    // MARK: - GPUPBRMaterial layout (BUG1: float3 padding)

    /// Metal expects `float3 emission` at offset 32 (16-byte alignment after `float ao` at 24).
    /// The Swift struct inserts `_padEmissionAlign: Float` at offset 28 to push `emissionR`
    /// from offset 28 (buggy) to offset 32 (correct).
    func testGPUPBRMaterialEmissionROffsetIs32() {
        let offset = MemoryLayout<GPUPBRMaterial>.offset(of: \.emissionR)
        XCTAssertEqual(offset, 32,
            "BUG1 regression: emissionR debe estar en offset 32 (alineacion float3 en Metal)")
    }

    /// The padding field that pushes emission to the correct offset.
    func testGPUPBRMaterialPadEmissionAlignOffsetIs28() {
        let offset = MemoryLayout<GPUPBRMaterial>.offset(of: \._padEmissionAlign)
        XCTAssertEqual(offset, 28,
            "_padEmissionAlign debe ocupar bytes 28-31, justo antes de emissionR en 32")
    }

    /// Full stride verification: 13 × Float = 52 bytes.
    /// Layout: [albedo+pad=16] [metallic/roughness/ao/pad=16] [emission+pad=16] [intensity=4] = 52.
    func testGPUPBRMaterialStrideIs52() {
        let stride = MemoryLayout<GPUPBRMaterial>.stride
        XCTAssertEqual(stride, 52,
            "stride esperado 52 bytes (13 campos Float × 4)")
    }

    /// Size matches stride for this struct (no trailing padding beyond alignment).
    func testGPUPBRMaterialSizeIs52() {
        let size = MemoryLayout<GPUPBRMaterial>.size
        XCTAssertEqual(size, 52,
            "size esperado 52 bytes")
    }

    /// Verify that the first row padding field sits at the correct offset.
    func testGPUPBRMaterialPad1OffsetIs12() {
        let offset = MemoryLayout<GPUPBRMaterial>.offset(of: \._pad1)
        XCTAssertEqual(offset, 12,
            "_pad1 debe ocupar bytes 12-15 (padding de float3 albedo a float4)")
    }

    /// Verify that the third row padding field sits at the correct offset.
    func testGPUPBRMaterialPad2OffsetIs44() {
        let offset = MemoryLayout<GPUPBRMaterial>.offset(of: \._pad2)
        XCTAssertEqual(offset, 44,
            "_pad2 debe ocupar bytes 44-47 (padding de float3 emission a float4)")
    }

    /// emissionIntensity sits at byte 48 (after the 16-byte emission group).
    /// In Metal PBRMaterialUniforms, `float3 emission` + `float emissionIntensity` = 16 bytes.
    /// Swift represents this as 16-byte group + 4-byte scalar = 20 bytes at same 16-byte boundary.
    func testGPUPBRMaterialEmissionIntensityOffsetIs48() {
        let offset = MemoryLayout<GPUPBRMaterial>.offset(of: \.emissionIntensity)
        XCTAssertEqual(offset, 48,
            "emissionIntensity debe estar en offset 48 (tras emision+_pad2 = 16 bytes)")
    }

    // MARK: - FrameUniforms layout (documented; struct is private)

    /// FrameUniforms is `private struct` in SatinRenderer.swift:10-16.
    /// We verify the building-block types match Metal expectations.
    /// Expected layout:
    ///   modelMatrix:      simd_float4x4  → 64 bytes @ 0
    ///   viewMatrix:       simd_float4x4  → 64 bytes @ 64
    ///   projectionMatrix: simd_float4x4  → 64 bytes @ 128
    ///   cameraPosition:   SIMD4<Float>   → 16 bytes @ 192
    ///   normalMatrix:     simd_float3x3  → 48 bytes @ 208
    ///   Total stride: 256 (padded to 16-byte alignment)
    ///
    /// Metal equivalent (PBRShaders.metal:21-27, IBLShaders.metal:18-24):
    ///   float4x4 modelMatrix; float4x4 viewMatrix; float4x4 projectionMatrix;
    ///   float4 cameraPosition; float3x3 normalMatrix;
    func testSimdFloat4x4MatchesMetalFloat4x4() {
        // Metal float4x4 = 4 columns × float4 = 4 × 16 bytes = 64 bytes
        XCTAssertEqual(MemoryLayout<simd_float4x4>.size, 64,
            "simd_float4x4 debe ser 64 bytes (igual que Metal float4x4)")
        XCTAssertEqual(MemoryLayout<simd_float4x4>.stride, 64,
            "simd_float4x4 stride debe ser 64 bytes")
    }

    /// SIMD4<Float> = 16 bytes, matches Metal float4.
    func testSimdFloat4MatchesMetalFloat4() {
        XCTAssertEqual(MemoryLayout<SIMD4<Float>>.size, 16,
            "SIMD4<Float> debe ser 16 bytes (igual que Metal float4)")
        XCTAssertEqual(MemoryLayout<SIMD4<Float>>.stride, 16,
            "SIMD4<Float> stride debe ser 16 bytes")
    }

    /// simd_float3x3 in Swift: 3 columns × SIMD3<Float> = 3 × 16 (stride) = 48 bytes.
    /// Metal float3x3: 3 columns × float3 = 3 × 16 (with padding) = 48 bytes in constant buffer.
    func testSimdFloat3x3MatchesMetalFloat3x3() {
        XCTAssertEqual(MemoryLayout<simd_float3x3>.stride, 48,
            "simd_float3x3 stride debe ser 48 bytes (3 columnas × 16 bytes c/u)")
        // size = 3 × 12 = 36 (raw data without inter-column padding)
        XCTAssertEqual(MemoryLayout<simd_float3x3>.size, 36,
            "simd_float3x3 size debe ser 36 bytes (9 floats × 4)")
    }

    /// Compute expected FrameUniforms stride from component sizes.
    /// 3 × float4x4 (64) + float4 (16) + float3x3 (48) = 256 bytes.
    func testFrameUniformsExpectedStrideIs256() {
        let expected = MemoryLayout<simd_float4x4>.stride * 3
                     + MemoryLayout<SIMD4<Float>>.stride
                     + MemoryLayout<simd_float3x3>.stride
        XCTAssertEqual(expected, 256,
            "FrameUniforms: 3×64 + 16 + 48 = 256 bytes (verifica contra Metal)")
    }

    // MARK: - BasicUniforms layout (documented; struct is private)

    /// BasicUniforms is `private struct` in SatinRenderer.swift:18-27.
    /// Expected layout:
    ///   modelMatrix:      simd_float4x4  → 64  @ 0
    ///   viewMatrix:       simd_float4x4  → 64  @ 64
    ///   projectionMatrix: simd_float4x4  → 64  @ 128
    ///   ambientColor:     SIMD3<Float>   → 16  @ 192 (SIMD3 aligned to 16)
    ///   lightDirection:   SIMD3<Float>   → 16  @ 208
    ///   lightColor:       SIMD3<Float>   → 16  @ 224
    ///   lightIntensity:   Float          → 4   @ 240
    ///   normalMatrix:     simd_float3x3  → 48  @ 256
    ///   Total stride: ~304 (padded to 16-byte alignment)
    ///
    /// Metal equivalent (Shaders.metal):
    ///   float4x4 modelMatrix; float4x4 viewMatrix; float4x4 projectionMatrix;
    ///   float3 ambientColor; float3 lightDirection; float3 lightColor;
    ///   float lightIntensity; float3x3 normalMatrix;
    func testSimdFloat3Alignment16InStructContext() {
        // SIMD3<Float>.stride = 16 en arrays (alineacion 16 para SIMD)
        // Dentro de un struct Swift, SIMD3 ocupa 12 bytes de datos
        // pero el siguiente campo se alinea a multiplo de 16 si es otro SIMD
        XCTAssertEqual(MemoryLayout<SIMD3<Float>>.alignment, 16,
            "SIMD3<Float> alineacion debe ser 16 (consistente con Metal float3 en constant buffer)")
    }

    /// Light intensity is a scalar Float (4 bytes).
    func testFloatIs4Bytes() {
        XCTAssertEqual(MemoryLayout<Float>.size, 4, "Float debe ser 4 bytes")
        XCTAssertEqual(MemoryLayout<Float>.stride, 4, "Float stride debe ser 4 bytes")
    }

    // MARK: - Mesh.indices type (BUG3: UInt32 verification)

    /// BUG3 (already fixed): Mesh.indices must be [UInt32], not [UInt16].
    /// Models with >65535 vertices require 32-bit indices.
    /// Verified: SatinRenderer.swift uses .uint32 indexType, stride is MemoryLayout<UInt32>.stride.
    func testMeshIndicesIsUInt32Array() {
        let mesh = Mesh()
        // Verificar que el tipo en tiempo de compilacion es [UInt32]
        let indices: [UInt32] = mesh.indices
        XCTAssertTrue(type(of: indices) == [UInt32].self,
            "BUG3 regression: Mesh.indices debe ser [UInt32], no [UInt16]")
    }

    /// Verify UInt32 stride matches Metal .uint32 index type.
    func testUInt32StrideMatchesMetalIndexType() {
        XCTAssertEqual(MemoryLayout<UInt32>.stride, 4,
            "UInt32 stride debe ser 4 bytes (Metal .uint32)")
    }
}
