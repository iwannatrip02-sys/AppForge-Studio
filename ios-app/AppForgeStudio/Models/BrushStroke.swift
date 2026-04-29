import Foundation
import simd

struct BrushPoint {
    var position: SIMD3<Float>
    var normal: SIMD3<Float>
    var pressure: Float
    var tilt: SIMD2<Float>
}

enum BrushType: String, Codable, CaseIterable {
    case round, flat, textured, airbrush, clay
    case inflate, pinch, smooth, crease, grab
}

enum StrokeMode: String, Codable {
    case paint, sculpt, hybrid
}

struct BrushStroke {
    var points: [BrushPoint]
    var brushType: BrushType
    var color: SIMD4<Float>
    var radius: Float
    var hardness: Float
    var opacity: Float
    var mode: StrokeMode
    
    init(brushType: BrushType = .round, color: SIMD4<Float> = SIMD4<Float>(0, 0, 0, 1), mode: StrokeMode = .paint) {
        self.points = []
        self.brushType = brushType
        self.color = color
        self.radius = 0.05
        self.hardness = 0.8
        self.opacity = 1.0
        self.mode = mode
    }
    
    mutating func addPoint(_ point: BrushPoint) {
        points.append(point)
    }
}

struct StrokeSegment {
    var start: BrushPoint
    var end: BrushPoint
    var segments: Int
    
    func interpolate() -> [BrushPoint] {
        var result: [BrushPoint] = []
        for i in 0...segments {
            let t = Float(i) / Float(segments)
            let pos = simd_mix(start.position, end.position, t)
            let nrm = simd_mix(start.normal, end.normal, t)
            let pres = start.pressure + (end.pressure - start.pressure) * t
            result.append(BrushPoint(position: pos, normal: nrm, pressure: pres, tilt: start.tilt))
        }
        return result
    }
}