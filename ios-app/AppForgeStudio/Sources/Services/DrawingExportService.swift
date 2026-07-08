import Foundation
import OCCTSwift
import simd
import OSLog

private let logger = Logger(subsystem: "com.appforgestudio", category: "DrawingExport")

/// Exportación de planos técnicos 2D (DXF) desde el B-rep de un modelo.
///
/// Capacidad CAD-profesional (Fase C): proyecta el sólido a vistas ortográficas de
/// ingeniería y las escribe como DXF R12 ASCII — el formato universal que abren
/// AutoCAD, LibreCAD, plotters y talleres. Shapr3D cobra los drawings; aquí son parte
/// del núcleo. Requiere `model.cadShape` (B-rep): un modelo solo-malla (esculpido/
/// importado sin B-rep) no tiene proyección de aristas exacta y se rechaza.
///
/// API del kernel usada (verificada contra OCCTSwift v1.8.8 — `mem:occtswift_api`):
/// `Drawing.topView/frontView/sideView/isometricView(of:) -> Drawing?` y
/// `DXFExporter.writeDXF(drawing:to:deflection:) throws`.
enum DrawingExportService {

    /// Vista ortográfica estándar de ingeniería (primer ángulo).
    enum StandardView: String, CaseIterable, Sendable {
        case top        // planta (mirando -Z)
        case front      // alzado
        case side       // vista lateral
        case isometric  // isométrica

        var displayName: String {
            switch self {
            case .top: return "Planta"
            case .front: return "Alzado"
            case .side: return "Lateral"
            case .isometric: return "Isométrica"
            }
        }
    }

    /// Construye el `Drawing` 2D de una vista ortográfica del shape (nil si la
    /// proyección OCCT falla, p.ej. geometría vacía o degenerada).
    static func drawing(of shape: CADShape, view: StandardView) -> Drawing? {
        switch view {
        case .top:       return Drawing.topView(of: shape)
        case .front:     return Drawing.frontView(of: shape)
        case .side:      return Drawing.sideView(of: shape)
        case .isometric: return Drawing.isometricView(of: shape)
        }
    }

    /// Exporta una vista del modelo como archivo DXF.
    /// - Returns: `true` si el archivo quedó escrito; `false` (con log) si el modelo
    ///   no tiene B-rep, la proyección falla o la escritura falla.
    @discardableResult
    static func exportDXF(_ model: Model, view: StandardView = .front, to url: URL,
                          deflection: Double = 0.1) -> Bool {
        guard let shape = model.cadShape else {
            logger.error("[DrawingExport] modelo '\(model.name)' sin B-rep — sin proyección exacta")
            return false
        }
        guard let draw = drawing(of: shape, view: view) else {
            logger.error("[DrawingExport] proyección \(view.rawValue) falló para '\(model.name)'")
            return false
        }
        do {
            try DXFExporter.writeDXF(drawing: draw, to: url, deflection: deflection)
            logger.info("[DrawingExport] DXF \(view.rawValue) escrito para '\(model.name)'")
            return true
        } catch {
            logger.error("[DrawingExport] escritura DXF falló: \(error.localizedDescription)")
            return false
        }
    }
}
