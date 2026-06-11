import Foundation
import SwiftUI
import simd

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
    
    let bevel = BevelEngine()
    let boolean = BooleanEngine()
    let loopCut = LoopCutEngine()
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
        case .booleanUnion:
            var offsetMesh = mesh
            for i in 0..<offsetMesh.vertices.count {
                offsetMesh.vertices[i].position.x += 0.15
            }
            mesh = boolean.booleanUnion(a: mesh, b: offsetMesh)
        case .fillet:
            guard let shape = occt.meshToShape(mesh) else { return }
            let result = occt.fillet(shape: shape, radius: Double(filletRadius))
            mesh = occt.shapeToMesh(result)
        case .chamfer:
            guard let shape = occt.meshToShape(mesh) else { return }
            let result = occt.chamfer(shape: shape, radius: Double(chamferRadius))
            mesh = occt.shapeToMesh(result)
        case .shell:
            guard let shape = occt.meshToShape(mesh) else { return }
            let result = occt.shell(shape: shape, thickness: Double(shellThickness))
            mesh = occt.shapeToMesh(result)
        case .loft:
            guard let shape = occt.meshToShape(mesh) else { return }
            let offsetShape = occt.createBox(width: 0.2, height: 0.2, depth: 0.2)
            let result = occt.loft(profiles: [shape, offsetShape])
            mesh = occt.shapeToMesh(result)
        case .sweep:
            guard let profileShape = occt.meshToShape(mesh) else { return }
            let path: [SIMD3<Double>] = [
                SIMD3<Double>(0, 0, 0),
                SIMD3<Double>(0, 0, Double(sweepHeight) * 1.0),
                SIMD3<Double>(0.2, 0, Double(sweepHeight) * 0.8),
                SIMD3<Double>(0.4, 0.1, Double(sweepHeight) * 0.6)
            ]
            let result = occt.sweep(profile: profileShape, along: path)
            mesh = occt.shapeToMesh(result)
        case .measure:
            if let shape = occt.meshToShape(mesh) {
                measurementArea = Float(occt.measureArea(shape))
                measurementVolume = Float(occt.measureVolume(shape))
                let box = occt.measureBoundingBox(shape)
                measurementDistance = Float(simd_distance(
                    SIMD3<Float>(Float(box.min.x), Float(box.min.y), Float(box.min.z)),
                    SIMD3<Float>(Float(box.max.x), Float(box.max.y), Float(box.max.z))
                ))
            }
            // TODO(F3): MeasureEngine fallback removed — CADShapeMeasureEngine uses CADShape API
        case .select, .move, .rotate, .scale:
            break
        case .line, .circle, .rectangle, .arc, .dimension, .constraint:
            break
        }
    }
}
