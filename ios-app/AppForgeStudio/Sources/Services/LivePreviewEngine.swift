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

    /// El fantasma debe ser EXACTAMENTE la operación que se va a confirmar.
    ///
    /// Antes no lo era en NINGUNO de los cuatro casos, y el estado ya traía los
    /// datos necesarios — solo se ignoraban:
    ///   · extrusión: hacía `extruded(by:)`, que barre el sólido ENTERO como un
    ///     prisma, cuando el commit hace push/pull sobre UNA cara.
    ///   · fillet y chaflán: usaban las variantes GLOBALES (todas las aristas)
    ///     teniendo el `edgeIndex` a mano, mientras el commit opera solo sobre
    ///     la arista elegida.
    ///   · vaciado: ligaba `openFaceIndex` y no lo usaba (el compilador avisaba
    ///     de la variable sin usar), así que previsualizaba una cáscara cerrada
    ///     y confirmaba una con la cara abierta.
    ///
    /// Un preview que miente es peor que no tener preview: arrastras confiando
    /// en lo que ves y sueltas sobre otra cosa.
    private func updateMesh(for parameter: Float) {
        guard let shape = originalShape else { return }
        let preview: CADShape?

        switch state {
        case .extruding(_, let faceIndex, _, _):
            // Mismo camino que `BRepModeling.pushPullFace`: la dirección la da
            // la NORMAL de la cara y el signo decide fusionar o restar.
            preview = BRepModeling.pushPullFace(shape, faceIndex: faceIndex,
                                                distance: Double(parameter))

        case .fillet(_, let edgeIndex, _):
            let all = shape.edges()
            preview = (edgeIndex >= 0 && edgeIndex < all.count)
                ? shape.filleted(edges: [all[edgeIndex]], radius: Double(parameter))
                : nil

        case .chamfer(_, let edgeIndex, _):
            let count = shape.edges().count
            preview = (edgeIndex >= 0 && edgeIndex < count)
                ? shape.chamferedWithFullHistory(distance: Double(parameter),
                                                 edges: [edgeIndex])?.result
                : nil

        case .shell(_, let openFaceIndex, _):
            if let fi = openFaceIndex {
                let faces = shape.faces()
                preview = (fi >= 0 && fi < faces.count)
                    ? shape.shelled(thickness: Double(parameter), openFaces: [faces[fi]])
                    : shape.shelled(thickness: Double(parameter))
            } else {
                preview = shape.shelled(thickness: Double(parameter))
            }

        case .inactive:
            preview = nil
        }

        if let preview = preview {
            previewMesh = OCCTBridge.toMesh(preview, quality: .low)
            previewEdges = OCCTBridge.edgesMesh(preview, radius: 0.005)
        } else {
            // La operación NO es válida con este parámetro (p. ej. un radio de
            // fillet mayor del que admite la arista). Sin este `else` el
            // fantasma anterior se quedaba congelado en pantalla y seguías
            // arrastrando creyendo que funcionaba. Retirarlo es la señal
            // honesta: si no hay ghost, ese valor no se puede aplicar.
            previewMesh = nil
            previewEdges = nil
        }
    }

    /// Estima el radio máximo de fillet para una arista (10% del tamaño del cuerpo)
    func estimateMaxFilletRadius(shape: CADShape) -> Float {
        let size = shape.size
        let minDim = Float(min(size.x, min(size.y, size.z)))
        return max(0.01, minDim * 0.15)
    }
}
