import Foundation
import simd

struct LODLevel: Codable, Hashable {
    let vertexCount: Int
    let simplificationRatio: Float
    let errorThreshold: Float
    
    static let high = LODLevel(vertexCount: 100000, simplificationRatio: 1.0, errorThreshold: 0.0)
    static let medium = LODLevel(vertexCount: 25000, simplificationRatio: 0.25, errorThreshold: 0.01)
    static let low = LODLevel(vertexCount: 5000, simplificationRatio: 0.05, errorThreshold: 0.05)
    static let veryLow = LODLevel(vertexCount: 1000, simplificationRatio: 0.01, errorThreshold: 0.1)
}

enum LODQuality: String, CaseIterable {
    case veryLow, low, medium, high
    
    var level: LODLevel {
        switch self {
        case .veryLow: return .veryLow
        case .low: return .low
        case .medium: return .medium
        case .high: return .high
        }
    }
}

@MainActor
final class LODManager {
    static let shared = LODManager()
    
    private var quality: LODQuality = .high
    
    func selectLOD(for vertexCount: Int, screenArea: Float) -> LODQuality {
        if screenArea < 0.01 { return .veryLow }
        if screenArea < 0.05 { return .low }
        if screenArea < 0.2 { return .medium }
        return quality
    }
    
    func setQuality(_ newQuality: LODQuality) {
        quality = newQuality
    }
}
