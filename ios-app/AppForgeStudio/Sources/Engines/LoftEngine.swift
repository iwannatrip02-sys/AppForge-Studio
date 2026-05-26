import Foundation
import simd
import OCCTSwift

/// Loft, shell, sweep, and revolve via OCCT B-rep.
@MainActor
final class LoftEngine {
    private let engine = OCCTEngine.shared
    
    func loft(profiles: [Wire], solid: Bool = true, quality: MeshQuality = .medium) -> Mesh {
        let result = engine.loft(profiles: profiles, solid: solid)
        return result?.appforgeMesh(quality: quality) ?? Mesh(vertices: [], indices: [])
    }
}

@MainActor
final class ShellEngine {
    private let engine = OCCTEngine.shared
    
    func shell(_ shape: CADShape, thickness: Double, quality: MeshQuality = .medium) -> Mesh {
        let result = engine.shell(shape, thickness: thickness)
        return result?.appforgeMesh(quality: quality) ?? shape.appforgeMesh(quality: quality)
    }
}

@MainActor
final class SweepEngine {
    private let engine = OCCTEngine.shared
    
    func sweep(profile: Wire, along path: Wire, quality: MeshQuality = .medium) -> Mesh {
        let result = engine.sweep(profile: profile, along: path)
        return result?.appforgeMesh(quality: quality) ?? Mesh(vertices: [], indices: [])
    }
}
