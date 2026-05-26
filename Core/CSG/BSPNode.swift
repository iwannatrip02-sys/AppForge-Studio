import Foundation
import simd

class BSPNode {
    var polygon: Polygon3D?
    var front: BSPNode?
    var back: BSPNode?
    var polygons: [Polygon3D] = []
    
    init() {}
    
    init(polygons: [Polygon3D], depth: Int = 0) {
        guard !polygons.isEmpty else { return }
        
        var bestSplitter: Polygon3D?
        var bestScore = Int.max
        let candidates = min(polygons.count, 5)
        
        for i in 0..<candidates {
            let poly = polygons[i]
            var frontCount = 0
            var backCount = 0
            for p in polygons {
                let classification = classify(p, against: poly.plane)
                switch classification {
                case .front: frontCount += 1
                case .back: backCount += 1
                default: break
                }
            }
            let score = abs(frontCount - backCount)
            if score < bestScore {
                bestScore = score
                bestSplitter = poly
            }
        }
        
        guard let splitter = bestSplitter else {
            self.polygons = polygons
            return
        }
        
        self.polygon = splitter
        var frontPolys: [Polygon3D] = []
        var backPolys: [Polygon3D] = []
        
        for p in polygons {
            let classification = classify(p, against: splitter.plane)
            switch classification {
            case .coplanar:
                if dot(p.normal, splitter.normal) > 0 {
                    frontPolys.append(p)
                } else {
                    backPolys.append(p)
                }
            case .front:
                frontPolys.append(p)
            case .back:
                backPolys.append(p)
            case .spanning:
                if let split = splitPolygon(p, by: splitter.plane) {
                    frontPolys.append(split.front)
                    backPolys.append(split.back)
                }
            }
        }
        
        if !frontPolys.isEmpty {
            front = BSPNode(polygons: frontPolys, depth: depth + 1)
        }
        if !backPolys.isEmpty {
            back = BSPNode(polygons: backPolys, depth: depth + 1)
        }
    }
    
    enum Classification {
        case coplanar, front, back, spanning
    }
    
    func classify(_ polygon: Polygon3D, against plane: (normal: SIMD3<Float>, d: Float)) -> Classification {
        var frontCount = 0
        var backCount = 0
        let epsilon: Float = 1e-6
        
        for v in polygon.vertices {
            let distance = dot(plane.normal, v) - plane.d
            if abs(distance) < epsilon {
                continue
            } else if distance > 0 {
                frontCount += 1
            } else {
                backCount += 1
            }
        }
        
        if frontCount > 0 && backCount > 0 {
            return .spanning
        } else if frontCount > 0 {
            return .front
        } else if backCount > 0 {
            return .back
        }
        return .coplanar
    }
    
    func splitPolygon(_ polygon: Polygon3D, by plane: (normal: SIMD3<Float>, d: Float)) -> (front: Polygon3D, back: Polygon3D)? {
        var frontVerts: [SIMD3<Float>] = []
        var backVerts: [SIMD3<Float>] = []
        let count = polygon.vertices.count
        let epsilon: Float = 1e-6
        
        for i in 0..<count {
            let a = polygon.vertices[i]
            let b = polygon.vertices[(i + 1) % count]
            let da = dot(plane.normal, a) - plane.d
            let db = dot(plane.normal, b) - plane.d
            
            if da >= -epsilon {
                frontVerts.append(a)
            }
            if da <= epsilon {
                backVerts.append(a)
            }
            
            if (da > epsilon && db < -epsilon) || (da < -epsilon && db > epsilon) {
                let t = -da / (db - da)
                let intersection = a + t * (b - a)
                frontVerts.append(intersection)
                backVerts.append(intersection)
            }
        }
        
        guard frontVerts.count >= 3, backVerts.count >= 3 else { return nil }
        return (
            front: Polygon3D(vertices: frontVerts, normal: polygon.normal),
            back: Polygon3D(vertices: backVerts, normal: polygon.normal)
        )
    }
    
    func allPolygons() -> [Polygon3D] {
        var result: [Polygon3D] = []
        if let poly = polygon {
            result.append(poly)
        }
        result.append(contentsOf: polygons)
        result.append(contentsOf: front?.allPolygons() ?? [])
        result.append(contentsOf: back?.allPolygons() ?? [])
        return result
    }
    
    func clip(_ polygon: Polygon3D, keepFront: Bool) -> [Polygon3D] {
        guard let poly = polygon else {
            return [polygon]
        }
        
        var frontPolys: [Polygon3D] = []
        
        for p in [polygon] {
            let classification = classify(p, against: poly.plane)
            switch classification {
            case .coplanar:
                if dot(p.normal, poly.normal) > 0 {
                    if keepFront { frontPolys.append(p) }
                } else {
                    if !keepFront { frontPolys.append(p) }
                }
            case .front:
                if let f = front {
                    frontPolys.append(contentsOf: f.clip(p, keepFront: keepFront))
                } else if keepFront {
                    frontPolys.append(p)
                }
            case .back:
                if let b = back {
                    backPolys.append(contentsOf: b.clip(p, keepFront: keepFront))
                } else if !keepFront {
                    frontPolys.append(p)
                }
            case .spanning:
                if let split = splitPolygon(p, by: poly.plane) {
                    if let f = front {
                        frontPolys.append(contentsOf: f.clip(split.front, keepFront: keepFront))
                    } else if keepFront {
                        frontPolys.append(split.front)
                    }
                    if let b = back {
                        frontPolys.append(contentsOf: b.clip(split.back, keepFront: keepFront))
                    } else if !keepFront {
                        frontPolys.append(split.back)
                    }
                }
            }
        }
        
        for p in self.polygons {
            frontPolys = frontPolys.filter { dot($0.normal, p.normal) > 0 == keepFront }
        }
        
        return frontPolys
    }
}
