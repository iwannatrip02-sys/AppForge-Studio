import Foundation
import SwiftUI
import simd

@MainActor
class ToolViewModel: ObservableObject {
    @Published var selectedTool: CADTool = .select
    @Published var gridSnapEnabled: Bool = false
    @Published var measurementDistance: Float = 0
    @Published var measurementArea: Float = 0
    @Published var measurementVolume: Float = 0
    @Published var isPaintMode: Bool = false
    @Published var radius: Float = 0.1
    @Published var filletRadius: Float = 0.05
    @Published var chamferRadius: Float = 0.05
    @Published var shellThickness: Float = 0.02
    @Published var sweepHeight: Float = 0.5
    @Published var csgShapeAIndex: Int? = nil
    @Published var csgShapeBIndex: Int? = nil
    @Published var csgActiveOperation: CADTool? = nil
    @Published var symmetryEnabled: Bool = false
    
    let bevel = BevelEngine()
    let boolean = BooleanEngine()
    let loopCut = LoopCutEngine()
    let chamferEngine = ChamferEngine()
    let shellEngine = ShellEngine()
    let sweepEngine = SweepEngine()
    let occt = OCCTEngine.shared
    // TODO(F3): ExtrusionEngine→CADShapeExtrusionEngine, MeasureEngine→CADShapeMeasureEngine pending migration
    
    func executeTool(mesh: inout Mesh) {
        switch selectedTool {
        case .extrude:
            // TODO(F3): re-wire ExtrusionEngine → CADShapeExtrusionEngine
            break
        case .loopCut:
            if mesh.indices.count >= 6 {
                let i0 = Int(mesh.indices[0]), i1 = Int(mesh.indices[1])
                _ = loopCut.loopCut(mesh: &mesh, edgeLoop: [(i0, i1)])
            }
        case .bevel:
            if mesh.indices.count >= 6 {
                let i0 = Int(mesh.indices[0]), i1 = Int(mesh.indices[1])
                _ = bevel.bevel(mesh: &mesh, edgeIndices: [(i0, i1)], bevelSize: 0.05, segments: 2)
            }
        case .booleanUnion, .booleanSubtract, .booleanIntersect:
            var offsetMesh = mesh
            for i in 0..<offsetMesh.vertices.count {
                offsetMesh.vertices[i].position.x += 0.15
            }
            switch selectedTool {
            case .booleanSubtract:
                mesh = boolean.booleanDifference(a: mesh, b: offsetMesh)
            case .booleanIntersect:
                mesh = boolean.booleanIntersection(a: mesh, b: offsetMesh)
            default:
                mesh = boolean.booleanUnion(a: mesh, b: offsetMesh)
            }
        case .fillet:
            // Mesh-based fillet ≈ bevel con segmentos (no hay puente Mesh→B-rep aún)
            if mesh.indices.count >= 6 {
                let i0 = Int(mesh.indices[0]), i1 = Int(mesh.indices[1])
                _ = bevel.bevel(mesh: &mesh, edgeIndices: [(i0, i1)], bevelSize: filletRadius, segments: 4)
            }
        case .chamfer:
            if mesh.indices.count >= 6 {
                let i0 = Int(mesh.indices[0]), i1 = Int(mesh.indices[1])
                _ = chamferEngine.computeChamfer(edges: [(i0, i1)], distance: chamferRadius, mesh: &mesh)
            }
        case .shell:
            _ = shellEngine.computeShell(faceIndex: 0, thickness: shellThickness, mesh: &mesh)
        case .loft:
            // TODO(F3): loft real requiere perfiles Wire (OCCT); falta puente Mesh→Wire
            break
        case .sweep:
            let path: [(position: SIMD3<Float>, tangent: SIMD3<Float>)] = [
                (SIMD3<Float>(0, 0, 0), SIMD3<Float>(0, 0, 1)),
                (SIMD3<Float>(0.05, 0, sweepHeight * 0.5), SIMD3<Float>(0, 0.2, 1)),
                (SIMD3<Float>(0, 0, sweepHeight), SIMD3<Float>(0, 0, 1))
            ]
            let swept = sweepEngine.computeSweep(profile: mesh.vertices, path: path, segments: 12)
            if !swept.vertices.isEmpty { mesh = swept }
        case .measure:
            // Medición directa sobre la malla (área por triángulos, volumen por tetraedros firmados)
            guard !mesh.vertices.isEmpty else { break }
            var minP = SIMD3<Float>(repeating: .greatestFiniteMagnitude)
            var maxP = SIMD3<Float>(repeating: -.greatestFiniteMagnitude)
            for v in mesh.vertices {
                minP = simd_min(minP, v.position)
                maxP = simd_max(maxP, v.position)
            }
            measurementDistance = simd_distance(minP, maxP)
            var area: Float = 0
            var volume: Float = 0
            var i = 0
            while i + 2 < mesh.indices.count {
                let a = mesh.vertices[Int(mesh.indices[i])].position
                let b = mesh.vertices[Int(mesh.indices[i + 1])].position
                let c = mesh.vertices[Int(mesh.indices[i + 2])].position
                area += simd_length(simd_cross(b - a, c - a)) * 0.5
                volume += simd_dot(a, simd_cross(b, c)) / 6
                i += 3
            }
            measurementArea = area
            measurementVolume = abs(volume)
        case .select, .move, .rotate, .scale:
            break
        case .revolve, .sketch, .pushPull, .hole:
            // revolve: requiere perfil Wire; sketch/pushPull/hole: controllers propios
            break
        case .line, .circle, .rectangle, .spline, .arc, .polygon, .dimension, .constraint:
            break
        }
    }
}
