import Foundation
import simd

enum CSGOperation {
    case union
    case difference
    case intersection
    
    func apply(_ meshA: Mesh, _ meshB: Mesh) -> Mesh {
        let polysA = Polygon3D.fromMesh(meshA)
        let polysB = Polygon3D.fromMesh(meshB)
        
        guard !polysA.isEmpty else { return meshB }
        guard !polysB.isEmpty else { return meshA }
        
        let treeA = BSPNode(polygons: polysA)
        let treeB = BSPNode(polygons: polysB)
        
        var result: [Polygon3D] = []
        
        switch self {
        case .union:
            let clippedA = polysA.flatMap { treeB.clip($0, keepFront: true) }
            let clippedB = polysB.flatMap { treeA.clip($0, keepFront: false) }
            result = clippedA + clippedB
        case .difference:
            let clippedA = polysA.flatMap { treeB.clip($0, keepFront: true) }
            let clippedB = polysB.flatMap { treeA.clip($0, keepFront: true) }
            result = clippedA + clippedB
        case .intersection:
            let clippedA = polysA.flatMap { treeB.clip($0, keepFront: false) }
            let clippedB = polysB.flatMap { treeA.clip($0, keepFront: false) }
            result = clippedA + clippedB
        }
        
        return Polygon3D.toMesh(result)
    }
}
