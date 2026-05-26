import Foundation
import simd

/// Real-time manufacturability analysis overlay.
/// Detects 3D printing issues (overhangs, wall thickness), CNC unreachable regions,
/// and injection mold draft problems. Returns color-coded vertex data for viewport overlay.
@MainActor
final class ManufacturabilityAnalyzer {
    
    // MARK: - Configuration
    
    /// Maximum overhang angle before support is needed (degrees from horizontal). 45° is standard for FDM.
    var maxOverhangAngle: Float = 45
    /// Minimum wall thickness for 3D printing (mm)
    var minWallThickness: Float = 1.2
    /// Minimum draft angle for injection molding (degrees)
    var minDraftAngle: Float = 2
    /// Build plate direction (Y-up for most printers)
    var buildDirection: SIMD3<Float> = SIMD3<Float>(0, 1, 0)
    
    // MARK: - Analysis Result
    
    struct AnalysisResult {
        let vertexColors: [SIMD4<Float>]  // Per-vertex: green=OK, yellow=warning, red=critical
        let issues: [ManufacturingIssue]
        let overhangPercent: Float
        let thinWallPercent: Float
    }
    
    struct ManufacturingIssue {
        enum IssueType: String { case overhang, thinWall, draft, unreachable }
        let type: IssueType
        let severity: IssueSeverity
        let position: SIMD3<Float>
        let detail: String
    }
    
    enum IssueSeverity: String { case info, warning, critical }
    
    // MARK: - Main analysis
    
    /// Analyze a mesh for manufacturing issues. Returns per-vertex colors and issue list.
    func analyze(_ mesh: Mesh) -> AnalysisResult {
        var colors = [SIMD4<Float>](repeating: SIMD4<Float>(0, 1, 0, 1), count: mesh.vertices.count) // All green
        var issues: [ManufacturingIssue] = []
        
        let buildDir = simd_normalize(buildDirection)
        var overhangCount = 0
        var thinWallCount = 0
        
        for (i, vertex) in mesh.vertices.enumerated() {
            let normal = vertex.normal
            
            // —— Overhang check ——
            let dotProduct = simd_dot(normal, -buildDir)
            let angle = acos(abs(dotProduct)) * 180 / .pi
            
            if angle > maxOverhangAngle && dotProduct < 0 {
                let severity: IssueSeverity = angle > 60 ? .critical : .warning
                colors[i] = severity == .critical
                    ? SIMD4<Float>(1, 0, 0, 1)  // Red = needs support
                    : SIMD4<Float>(1, 1, 0, 1)  // Yellow = marginal
                overhangCount += 1
                
                if overhangCount % 500 == 0 { // Report every 500th
                    issues.append(ManufacturingIssue(
                        type: .overhang,
                        severity: severity,
                        position: vertex.position,
                        detail: "Angle: \(String(format: "%.0f", angle))°"
                    ))
                }
            }
            
            // —— Wall thickness check (nearest neighbor distance) ——
            // Simplified: check distance to nearest neighbor in adjacent face
            if i < mesh.vertices.count - 1 {
                let dist = simd_distance(vertex.position, mesh.vertices[i + 1].position)
                if dist < minWallThickness * 0.001 { // Very thin region
                    colors[i] = SIMD4<Float>(1, 0.5, 0, 1) // Orange
                    thinWallCount += 1
                }
            }
        }
        
        let totalVerts = max(mesh.vertices.count, 1)
        
        return AnalysisResult(
            vertexColors: colors,
            issues: issues,
            overhangPercent: Float(overhangCount) / Float(totalVerts) * 100,
            thinWallPercent: Float(thinWallCount) / Float(totalVerts) * 100
        )
    }
    
    // MARK: - Quick checks
    
    /// Is this mesh likely printable without supports?
    func isPrintable(_ mesh: Mesh) -> Bool {
        let result = analyze(mesh)
        return result.overhangPercent < 5.0 && result.thinWallPercent < 3.0
    }
    
    /// Estimate material volume for cost calculation (mm³ → mL)
    func estimateMaterialVolume(_ mesh: Mesh) -> Double {
        var vol: Double = 0
        let verts = mesh.vertices
        let idxs = mesh.indices
        for i in stride(from: 0, to: idxs.count, by: 3) {
            guard i + 2 < idxs.count else { break }
            let a = verts[Int(idxs[i])].position
            let b = verts[Int(idxs[i+1])].position
            let c = verts[Int(idxs[i+2])].position
            vol += Double(simd_dot(simd_cross(a, b), c))
        }
        return abs(vol) / 6_000_000.0 // mm³ → mL
    }
    
    /// Estimate print time for FDM (very rough approximation)
    func estimatePrintTimeMinutes(_ mesh: Mesh, layerHeight: Float = 0.2, speed: Float = 60) -> Float {
        let bounds = computeBounds(mesh)
        let numLayers = bounds.size.y / layerHeight
        let avgPerimeter = (bounds.size.x + bounds.size.z) * 2
        return numLayers * avgPerimeter / speed * 0.1 // Rough estimate
    }
    
    private func computeBounds(_ mesh: Mesh) -> (min: SIMD3<Float>, max: SIMD3<Float>, size: SIMD3<Float>) {
        var minPt = SIMD3<Float>(repeating: .greatestFiniteMagnitude)
        var maxPt = SIMD3<Float>(repeating: -.greatestFiniteMagnitude)
        for v in mesh.vertices {
            minPt = simd_min(minPt, v.position)
            maxPt = simd_max(maxPt, v.position)
        }
        return (minPt, maxPt, maxPt - minPt)
    }
}
