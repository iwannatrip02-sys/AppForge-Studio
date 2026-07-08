import Foundation
import OSLog

private let logger = Logger(subsystem: "com.appforgestudio", category: "FeatureReportController")

/// Controlador del reconocimiento de features de fabricación (agujeros y cajeras).
///
/// Sigue el patrón `@MainActor ObservableObject` del proyecto: la vista solo
/// bindea `statusMessage` y `report`; la lógica y el estado viven aquí.
/// Testeable de forma aislada sin dependencia de vistas.
@MainActor
final class FeatureReportController: ObservableObject {

    // MARK: - Estado observable

    /// Mensaje de estado en español (máximo una línea) para la barra o encabezado de sheet.
    @Published private(set) var statusMessage: String = "Selecciona un modelo con B-rep y toca Reconocer"

    /// Resultado del último análisis; nil si no se ha analizado nada o el modelo no tiene B-rep.
    @Published private(set) var report: FeatureRecognitionService.Report? = nil

    /// true mientras se ejecuta el análisis AAG.
    @Published private(set) var isBusy: Bool = false

    // MARK: - Análisis

    /// Analiza las features de fabricación del B-rep del modelo dado.
    ///
    /// Actualiza `report` y `statusMessage`. Si el modelo no tiene B-rep (esculpido/
    /// importado solo-malla), `report` queda nil y `statusMessage` lo explica.
    ///
    /// - Parameter model: El modelo a analizar (debe tener `cadShape` para obtener resultados).
    func analyze(model: Model) {
        guard model.cadShape != nil else {
            statusMessage = "Sin B-rep — features no disponibles para este modelo"
            report = nil
            return
        }
        isBusy = true
        statusMessage = "Analizando features…"
        let result = FeatureRecognitionService.analyze(model)
        report = result
        statusMessage = result?.summary ?? "Sin B-rep — features no disponibles"
        isBusy = false
        logger.info("[FeatureCtrl] análisis completo: \(result?.summary ?? "nil")")
    }

    // MARK: - Reset

    /// Limpia el resultado anterior (al cerrar la sheet o al cambiar de modelo).
    func reset() {
        report = nil
        statusMessage = "Selecciona un modelo con B-rep y toca Reconocer"
        isBusy = false
    }
}
