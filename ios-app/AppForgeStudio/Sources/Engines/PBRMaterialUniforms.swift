import Foundation
import Metal
import Combine

class PBRMaterialUniforms: ObservableObject {
    @Published var irradianceMap: MTLTexture?
    @Published var prefilterMap: MTLTexture?
    @Published var brdfLUT: MTLTexture?
    @Published var textures: [String: MTLTexture]?
    var prefilterMipLevels: Int = 5

    func setupIBL(pipeline: IBLPipeline, hdriTexture: MTLTexture) {
        guard let result = pipeline.generate(from: hdriTexture) else { return }
        irradianceMap = result.irradiance
        prefilterMap = result.prefilter
        brdfLUT = result.brdfLUT
    }
    
    func bindTextures(encoder: MTLRenderCommandEncoder) {
        guard let textures = textures else { return }
        if let tex = textures["albedo"] { encoder.setFragmentTexture(tex, index: 3) }
        if let tex = textures["normal"] { encoder.setFragmentTexture(tex, index: 4) }
        if let tex = textures["metallic"] { encoder.setFragmentTexture(tex, index: 5) }
        if let tex = textures["roughness"] { encoder.setFragmentTexture(tex, index: 6) }
        if let tex = textures["ao"] { encoder.setFragmentTexture(tex, index: 7) }
        if let tex = textures["emissive"] { encoder.setFragmentTexture(tex, index: 8) }
    }
}
