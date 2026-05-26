import Foundation
import simd

struct MorphEngine {

    static func createMorphTarget(from mesh: Mesh, name: String, deformedVertices: [Vertex]) -> MorphTarget {
        let base = mesh.baseVertices.isEmpty ? mesh.vertices : mesh.baseVertices
        let count = min(base.count, deformedVertices.count)
        var offsets = [SIMD3<Float>](repeating: .zero, count: count)
        for i in 0..<count {
            offsets[i] = deformedVertices[i].position - base[i].position
        }
        return MorphTarget(name: name, offsets: offsets, weight: 0)
    }

    static func applyAllMorphs(to mesh: inout Mesh, at time: Float, clip: AnimationClip) {
        for (morphName, frames) in clip.morphFrames {
            guard let index = mesh.morphTargets.firstIndex(where: { $0.name == morphName }) else { continue }
            let sorted = frames.sorted { $0.time < $1.time }
            guard sorted.count >= 2 else {
                mesh.morphTargets[index].weight = sorted.first?.value ?? 0
                continue
            }
            var prev = sorted[0]
            var next = sorted.last!
            for i in 0..<(sorted.count - 1) {
                if time >= sorted[i].time && time <= sorted[i+1].time {
                    prev = sorted[i]
                    next = sorted[i+1]
                    break
                }
            }
            if next.time == prev.time {
                mesh.morphTargets[index].weight = prev.value
            } else {
                let t = (time - prev.time) / (next.time - prev.time)
                mesh.morphTargets[index].weight = prev.value + (next.value - prev.value) * t
            }
        }
        mesh.applyMorphs()
    }

    static func blendMorphs(on mesh: inout Mesh, weights: [String: Float]) {
        for (name, weight) in weights {
            guard let index = mesh.morphTargets.firstIndex(where: { $0.name == name }) else { continue }
            mesh.morphTargets[index].weight = weight
        }
        mesh.applyMorphs()
    }
}
