import Foundation
import OSLog

private let logger = Logger(subsystem: "com.appforgestudio", category: "DrawingExportController")

/// Controlador de la barra de exportación de planos técnicos (DXF/PDF) en CADModeView.
///
/// Sigue el patrón `@MainActor ObservableObject` del proyecto: dueño del estado
/// de selección de vista, progreso y URL del archivo exportado. La vista solo
/// bindea; la lógica vive aquí y es testeable de forma aislada.
///
/// Uso típico desde la vista:
/// ```swift
/// let ok = controller.exportDXF(model: model)
/// if ok { /* presentar share sheet con controller.exportURL */ }
/// ```
@MainActor
final class DrawingExportController: ObservableObject {

    // MARK: - Estado observable

    /// Vista ortográfica que se exportará (Planta / Alzado / Lateral / Isométrica).
    @Published var selectedView: DrawingExportService.StandardView = .front

    /// Mensaje de estado en español para la barra (máximo una línea).
    @Published private(set) var statusMessage: String = "Selecciona una vista y el formato"

    /// URL del último archivo exportado; no nil cuando listo para compartir.
    @Published private(set) var exportURL: URL? = nil

    /// true mientras se genera el archivo (bloquea los botones de export).
    @Published private(set) var isBusy: Bool = false

    // MARK: - Exportación DXF

    /// Exporta la vista seleccionada del modelo como DXF R12 a /tmp.
    ///
    /// - Parameter model: Modelo con B-rep vivo (`cadShape != nil`).
    /// - Returns: true si el archivo quedó escrito; false con `statusMessage` descriptivo.
    @discardableResult
    func exportDXF(model: Model) -> Bool {
        guard model.cadShape != nil else {
            statusMessage = "Sin B-rep — plano no disponible"
            exportURL = nil
            return false
        }
        isBusy = true
        exportURL = nil
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(model.name)_\(selectedView.rawValue)")
            .appendingPathExtension("dxf")
        let ok = DrawingExportService.exportDXF(model, view: selectedView, to: url)
        if ok {
            exportURL = url
            statusMessage = "DXF listo — \(selectedView.displayName)"
            logger.info("[ExportCtrl] DXF generado: \(url.lastPathComponent)")
        } else {
            statusMessage = "Error al generar el plano DXF"
        }
        isBusy = false
        return ok
    }

    // MARK: - Exportación PDF

    /// Exporta la vista seleccionada del modelo como PDF imprimible (A4 apaisado) a /tmp.
    ///
    /// - Parameter model: Modelo con B-rep vivo (`cadShape != nil`).
    /// - Returns: true si el archivo quedó escrito; false con `statusMessage` descriptivo.
    @discardableResult
    func exportPDF(model: Model) -> Bool {
        guard model.cadShape != nil else {
            statusMessage = "Sin B-rep — plano no disponible"
            exportURL = nil
            return false
        }
        isBusy = true
        exportURL = nil
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(model.name)_\(selectedView.rawValue)")
            .appendingPathExtension("pdf")
        let ok = DrawingExportService.exportPDF(model, view: selectedView, to: url)
        if ok {
            exportURL = url
            statusMessage = "PDF listo — \(selectedView.displayName)"
            logger.info("[ExportCtrl] PDF generado: \(url.lastPathComponent)")
        } else {
            statusMessage = "Error al generar el plano PDF"
        }
        isBusy = false
        return ok
    }

    // MARK: - Reset

    /// Limpia el estado al cerrar la barra de exportación.
    func reset() {
        exportURL = nil
        statusMessage = "Selecciona una vista y el formato"
        isBusy = false
    }
}
