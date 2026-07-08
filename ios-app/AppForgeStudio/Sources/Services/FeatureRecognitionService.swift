import Foundation
import OCCTSwift
import simd
import OSLog

private let logger = Logger(subsystem: "com.appforgestudio", category: "FeatureRecognition")

/// Reconocimiento de features de fabricación desde el B-rep (agujeros, cajeras).
///
/// Capacidad CAD-profesional (Fase C): un sólido no es solo triángulos, es un conjunto
/// de *features* (holes, pockets, bosses). Reconocerlas habilita: selección inteligente
/// (tocar un agujero selecciona la feature entera), árbol de features tipo Fusion360, y
/// auto-acotado de planos. Es lo que distingue un modelador de un visor. Nomad no tiene CAD;
/// Shapr3D no expone feature recognition programable.
///
/// Motor: el AAG (Attributed Adjacency Graph) de OCCTSwift — grafo de caras con convexidad
/// de aristas. API verificada contra v1.8.8 (`mem:occtswift_api`): `Shape.buildAAG()`,
/// `AAG.detectPockets() -> [PocketFeature]`, `AAG.detectHoles() -> [(faceIndex,radius,depth)]`.
enum FeatureRecognitionService {

    /// Agujero cilíndrico reconocido (taladrado o boolean con cilindro).
    struct Hole: Identifiable, Sendable {
        let id = UUID()
        let faceIndex: Int
        let radius: Double
        let depth: Double
        var diameter: Double { radius * 2 }
    }

    /// Cajera (pocket): un piso plano rodeado de paredes, excavado del sólido.
    struct Pocket: Identifiable, Sendable {
        let id = UUID()
        let floorFaceIndex: Int
        let wallFaceIndices: [Int]
        let depth: Double
        /// Cajera abierta por un lado (ranura) vs. cerrada (bolsillo).
        let isOpen: Bool
    }

    /// Resultado del análisis de features de un sólido.
    struct Report: Sendable {
        let holes: [Hole]
        let pockets: [Pocket]

        var isEmpty: Bool { holes.isEmpty && pockets.isEmpty }

        /// Resumen en español para la barra de estado / árbol de features.
        var summary: String {
            if isEmpty { return "Sin features reconocidas" }
            var parts: [String] = []
            if !holes.isEmpty { parts.append("\(holes.count) agujero\(holes.count == 1 ? "" : "s")") }
            if !pockets.isEmpty { parts.append("\(pockets.count) cajera\(pockets.count == 1 ? "" : "s")") }
            return parts.joined(separator: ", ")
        }
    }

    /// Analiza el B-rep de un modelo. Devuelve nil si el modelo no tiene B-rep
    /// (esculpido/importado solo-malla: sin topología de caras que reconocer).
    static func analyze(_ model: Model) -> Report? {
        guard let shape = model.cadShape else {
            logger.info("[FeatureRecognition] modelo '\(model.name)' sin B-rep — nada que reconocer")
            return nil
        }
        return analyze(shape)
    }

    /// Analiza un B-rep directamente.
    static func analyze(_ shape: CADShape) -> Report {
        let aag = shape.buildAAG()
        let holes = aag.detectHoles().map {
            Hole(faceIndex: $0.faceIndex, radius: $0.radius, depth: $0.depth)
        }
        let pockets = aag.detectPockets().map {
            Pocket(floorFaceIndex: $0.floorFaceIndex,
                   wallFaceIndices: $0.wallFaceIndices,
                   depth: $0.depth,
                   isOpen: $0.isOpen)
        }
        logger.info("[FeatureRecognition] \(holes.count) agujeros, \(pockets.count) cajeras")
        return Report(holes: holes, pockets: pockets)
    }
}
