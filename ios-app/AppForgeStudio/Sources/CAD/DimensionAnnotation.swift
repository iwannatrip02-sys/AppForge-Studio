import Foundation
import simd
import CoreGraphics

// MARK: - Tipos de cota 3D

enum DimensionType: String, Codable, CaseIterable {
    case linear     // Distancia entre dos puntos
    case radius     // Radio de círculo/arco
    case diameter   // Diámetro de círculo
    case angle      // Ángulo entre tres puntos
    case aligned    // Distancia alineada a una dirección
}

/// Una cota/acotación en el espacio 3D, proyectada a pantalla para visualización.
struct DimensionAnnotation: Identifiable, Equatable {
    let id: UUID
    var type: DimensionType
    /// Puntos 3D de referencia (2 para linear/aligned, 1 centro + 1 borde para radius, 3 para angle)
    var anchorPoints: [SIMD3<Float>]
    /// Valor medido (calculado)
    var measuredValue: Float
    /// Unidad de display
    var unit: String
    /// Etiqueta opcional (ej: "R 5.00")
    var label: String
    /// Color de la cota
    var color: SIMD4<Float>
    /// Si la cota está siendo arrastrada/Editada
    var isEditing: Bool
    /// Offset en espacio pantalla para la línea de cota (distancia desde los puntos medidos)
    var screenOffset: CGFloat

    init(id: UUID = UUID(),
         type: DimensionType,
         anchorPoints: [SIMD3<Float>],
         unit: String = "mm",
         label: String? = nil,
         color: SIMD4<Float> = SIMD4<Float>(1.0, 0.48, 0.27, 1.0),
         screenOffset: CGFloat = 40) {
        self.id = id
        self.type = type
        self.anchorPoints = anchorPoints
        self.measuredValue = DimensionAnnotation.computeValue(type: type, points: anchorPoints)
        self.unit = unit
        self.label = label ?? DimensionAnnotation.formatValue(type: type, value: measuredValue, unit: unit)
        self.color = color
        self.isEditing = false
        self.screenOffset = screenOffset
    }

    /// Recalcula el valor medido y actualiza la etiqueta
    mutating func recompute() {
        measuredValue = DimensionAnnotation.computeValue(type: type, points: anchorPoints)
        label = DimensionAnnotation.formatValue(type: type, value: measuredValue, unit: unit)
    }

    private static func computeValue(type: DimensionType, points: [SIMD3<Float>]) -> Float {
        switch type {
        case .linear, .aligned:
            guard points.count >= 2 else { return 0 }
            return simd_distance(points[0], points[1])
        case .radius:
            guard points.count >= 2 else { return 0 }
            return simd_distance(points[0], points[1])
        case .diameter:
            guard points.count >= 2 else { return 0 }
            return simd_distance(points[0], points[1]) * 2
        case .angle:
            guard points.count >= 3 else { return 0 }
            let v1 = simd_normalize(points[1] - points[0])
            let v2 = simd_normalize(points[2] - points[0])
            let dot = simd_dot(v1, v2)
            return acos(clamp(dot, -1, 1)) * 180 / .pi
        }
    }

    private static func formatValue(type: DimensionType, value: Float, unit: String) -> String {
        switch type {
        case .angle:
            return String(format: "%.1f°", value)
        case .radius:
            return String(format: "R %.2f %@", value, unit)
        case .diameter:
            return String(format: "⌀ %.2f %@", value, unit)
        case .linear, .aligned:
            return String(format: "%.2f %@", value, unit)
        }
    }
}

private func clamp(_ value: Float, _ minVal: Float, _ maxVal: Float) -> Float {
    Swift.min(Swift.max(value, minVal), maxVal)
}

// MARK: - Gestor de cotas

/// Administra el conjunto de cotas en la escena. Las cotas se crean por el usuario
/// (modo Medir) o automáticamente al seleccionar entidades.
@MainActor
final class DimensionManager: ObservableObject {
    @Published var annotations: [DimensionAnnotation] = []
    @Published var activeAnnotationID: UUID?
    @Published var showDimensions: Bool = true

    /// Agrega una cota lineal entre dos puntos
    @discardableResult
    func addLinear(from: SIMD3<Float>, to: SIMD3<Float>, label: String? = nil) -> DimensionAnnotation {
        var ann = DimensionAnnotation(
            type: .linear,
            anchorPoints: [from, to],
            label: label
        )
        annotations.append(ann)
        activeAnnotationID = ann.id
        return ann
    }

    /// Agrega una cota de radio (centro + punto en borde)
    @discardableResult
    func addRadius(center: SIMD3<Float>, edgePoint: SIMD3<Float>, label: String? = nil) -> DimensionAnnotation {
        var ann = DimensionAnnotation(
            type: .radius,
            anchorPoints: [center, edgePoint],
            label: label,
            color: SIMD4<Float>(0.3, 0.7, 1.0, 1.0)  // azul para radios
        )
        annotations.append(ann)
        activeAnnotationID = ann.id
        return ann
    }

    /// Agrega una cota de ángulo (vértice + dos puntos)
    @discardableResult
    func addAngle(vertex: SIMD3<Float>, pointA: SIMD3<Float>, pointB: SIMD3<Float>, label: String? = nil) -> DimensionAnnotation {
        var ann = DimensionAnnotation(
            type: .angle,
            anchorPoints: [vertex, pointA, pointB],
            label: label,
            color: SIMD4<Float>(0.3, 1.0, 0.6, 1.0)  // verde para ángulos
        )
        annotations.append(ann)
        activeAnnotationID = ann.id
        return ann
    }

    /// Actualiza el segundo punto de la cota activa (durante medición interactiva)
    func updateActiveEndpoint(_ point: SIMD3<Float>) {
        guard let id = activeAnnotationID,
              let idx = annotations.firstIndex(where: { $0.id == id }),
              annotations[idx].anchorPoints.count >= 2 else { return }
        annotations[idx].anchorPoints[1] = point
        annotations[idx].recompute()
    }

    /// Elimina la cota activa
    func removeActive() {
        guard let id = activeAnnotationID else { return }
        annotations.removeAll { $0.id == id }
        activeAnnotationID = nil
    }

    /// Elimina todas las cotas
    func clearAll() {
        annotations.removeAll()
        activeAnnotationID = nil
    }

    /// Cotas que están cerca de un punto 3D (para selección táctil)
    func annotationsNear(_ point: SIMD3<Float>, maxDistance: Float = 0.5) -> [DimensionAnnotation] {
        annotations.filter { ann in
            ann.anchorPoints.contains { simd_distance($0, point) < maxDistance }
        }
    }
}
