import Foundation
import simd
import OCCTSwift
import OSLog

private let logger = Logger(subsystem: "com.appforgestudio", category: "LivePreview")

// MARK: - Estado del preview en vivo

/// Describe el preview activo: qué operación, sobre qué geometría, con qué parámetros.
enum LivePreviewState: Equatable {
    case inactive
    case extruding(modelIndex: Int, faceIndex: Int, direction: SIMD3<Float>, distance: Float)
    case fillet(modelIndex: Int, edgeIndex: Int, radius: Float)
    case chamfer(modelIndex: Int, edgeIndex: Int, distance: Float)
    case shell(modelIndex: Int, openFaceIndex: Int?, thickness: Float)

    var isActive: Bool {
        if case .inactive = self { return false }
        return true
    }
}

// MARK: - Motor de preview en vivo

/// Genera mallas fantasma (translúcidas, color ámbar) que muestran
/// el resultado de una operación antes de confirmarla.
///
/// Flujo:
/// 1. Usuario selecciona cara/arista → `begin*(...)`
/// 2. Usuario arrastra → `update(parameter:)` → regenera mesh preview
/// 3. Usuario suelta → `commit()` → aplica la operación real al B-rep vía BRepModeling
/// 4. Usuario cancela → `cancel()` → limpia el preview
@MainActor
final class LivePreviewEngine: ObservableObject {
    @Published var state: LivePreviewState = .inactive
    /// Mesh del preview (translúcido) — nil si no hay preview activo
    @Published var previewMesh: Mesh?
    /// Mesh de aristas del preview
    @Published var previewEdges: Mesh?

    private var originalShape: CADShape?
    private var originalEdges: Mesh?
    /// Callback que se llama al hacer commit (el owner aplica la operación real)
    var onCommit: ((LivePreviewState) -> Void)?

    // MARK: - Preview lifecycle

    /// Inicia el preview de extrusión sobre una cara.
    func beginExtrude(shape: CADShape, faceIndex: Int,
                      direction: SIMD3<Float>, initialDistance: Float = 0.1) {
        originalShape = shape
        state = .extruding(modelIndex: -1, faceIndex: faceIndex,
                          direction: direction, distance: initialDistance)
        updateMesh(for: initialDistance)
    }

    /// Inicia el preview de redondeo sobre una arista.
    func beginFillet(shape: CADShape, edgeIndex: Int, initialRadius: Float = 0.05) {
        originalShape = shape
        state = .fillet(modelIndex: -1, edgeIndex: edgeIndex, radius: initialRadius)
        updateMesh(for: initialRadius)
    }

    /// Inicia el preview de chaflán.
    func beginChamfer(shape: CADShape, edgeIndex: Int, initialDistance: Float = 0.05) {
        originalShape = shape
        state = .chamfer(modelIndex: -1, edgeIndex: edgeIndex, distance: initialDistance)
        updateMesh(for: initialDistance)
    }

    /// Inicia el preview de vaciado.
    func beginShell(shape: CADShape, openFaceIndex: Int?, initialThickness: Float = 0.08) {
        originalShape = shape
        state = .shell(modelIndex: -1, openFaceIndex: openFaceIndex, thickness: initialThickness)
        updateMesh(for: initialThickness)
    }

    // MARK: - Update (durante drag)

    /// Actualiza el parámetro activo del preview.
    func update(parameter: Float) {
        switch state {
        case .extruding(let m, let f, let d, _):
            state = .extruding(modelIndex: m, faceIndex: f, direction: d, distance: parameter)
        case .fillet(let m, let e, _):
            state = .fillet(modelIndex: m, edgeIndex: e, radius: parameter)
        case .chamfer(let m, let e, _):
            state = .chamfer(modelIndex: m, edgeIndex: e, distance: parameter)
        case .shell(let m, let f, _):
            state = .shell(modelIndex: m, openFaceIndex: f, thickness: parameter)
        case .inactive:
            return
        }
        updateMesh(for: parameter)
    }

    // MARK: - Commit / Cancel

    /// Confirma la operación y notifica al owner.
    func commit() {
        onCommit?(state)
        clear()
    }

    /// Cancela el preview sin aplicar cambios.
    func cancel() {
        clear()
    }

    private func clear() {
        state = .inactive
        previewMesh = nil
        previewEdges = nil
        originalShape = nil
        originalEdges = nil
    }

    // MARK: - Generación de mesh preview (OCCT low-quality)

    private func updateMesh(for parameter: Float) {
        guard let shape = originalShape else { return }
        let preview: CADShape?

        switch state {
        case .extruding(_, _, let dir, _):
            let d3 = SIMD3<Double>(Double(dir.x), Double(dir.y), Double(dir.z))
            let vec = d3 * Double(parameter)
            preview = shape.extruded(by: vec)

        case .fillet:
            preview = shape.filleted(radius: Double(parameter))

        case .chamfer:
            preview = shape.chamfered(distance: Double(parameter))

        case .shell(_, let face, _):
            preview = shape.shelled(thickness: Double(parameter))

        case .inactive:
            preview = nil
        }

        if let preview = preview {
            previewMesh = OCCTBridge.toMesh(preview, quality: .low)
            previewEdges = OCCTBridge.edgesMesh(preview, radius: 0.005)
        }
    }

    /// Estima el radio máximo de fillet para una arista (10% del tamaño del cuerpo)
    func estimateMaxFilletRadius(shape: CADShape) -> Float {
        let size = shape.size
        let minDim = Float(min(size.x, min(size.y, size.z)))
        return max(0.01, minDim * 0.15)
    }
}
