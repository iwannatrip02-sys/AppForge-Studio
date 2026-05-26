import Foundation
import SwiftUI
import UniformTypeIdentifiers
import OSLog

private let logger = Logger(subsystem: "com.appforgestudio", category: "ExportViewModel")
@MainActor
class ExportViewModel: ObservableObject {
    enum ExportFormat: String, CaseIterable, Identifiable {
        case obj = "OBJ"
        case stl = "STL"
        case step = "STEP"
        case usdz = "USDZ"
        case fbx = "FBX"
        var id: String { rawValue }
        var fileExtension: String {
            switch self {
            case .obj: return "obj"
            case .stl: return "stl"
            case .step: return "step"
            case .usdz: return "usdz"
            case .fbx: return "fbx"
            }
        }
        var description: String {
            switch self {
            case .obj: return "Wavefront OBJ"
            case .stl: return "Estereolitografia"
            case .step: return "STEP CAD"
            case .usdz: return "Universal Scene Description"
            case .fbx: return "Autodesk FBX"
            }
        }
        var icon: String {
            switch self {
            case .stl: return "cube.fill"
            case .obj: return "doc.text.fill"
            case .step: return "gearshape.fill"
            case .usdz: return "arkit"
            case .fbx: return "square.3.layers.3d"
            }
        }
        var utType: UTType {
            switch self {
            case .obj: return UTType(filenameExtension: "obj") ?? .data
            case .stl: return UTType(filenameExtension: "stl") ?? .data
            case .step: return UTType(filenameExtension: "step") ?? .data
            case .usdz: return UTType(filenameExtension: "usdz") ?? .data
            case .fbx: return UTType(filenameExtension: "fbx") ?? .data
            }
        }
    }

    @Published var selectedFormat: ExportFormat = .stl
    @Published var isExporting = false
    @Published var exportProgress: Float = 0.0
    @Published var exportError: String?
    @Published var showSuccessAlert = false
    @Published var exportedFileURL: URL?
    @Published var selectedModel: Model?

    let exportService: ExportService
    let exportServiceSTEP: ExportServiceSTEP

    init(exportService: ExportService, exportServiceSTEP: ExportServiceSTEP = ExportServiceSTEP()) {
        self.exportService = exportService
        self.exportServiceSTEP = exportServiceSTEP
    }

    func exportModel(fileName: String) async {
        guard let model = selectedModel else {
            exportError = "No hay modelo seleccionado para exportar."
            return
        }
        isExporting = true
        exportError = nil
        exportProgress = 0.0
        exportedFileURL = nil

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(fileName)
            .appendingPathExtension(selectedFormat.fileExtension)

        exportProgress = 0.3

        let mappedFormat: ExportFormat
        switch selectedFormat {
        case .obj: mappedFormat = .obj
        case .stl: mappedFormat = .stl
        case .step: mappedFormat = .step
        case .usdz: mappedFormat = .usdz
        case .fbx: mappedFormat = .fbx
        }

        let result: Result<Void, ExportError>
        if selectedFormat == .step {
            guard let mesh = model.meshes.first else {
                exportError = "No hay malla para exportar STEP."
                isExporting = false
                return
            }
            do {
                try exportServiceSTEP.exportMeshToSTEP(mesh: mesh, outputURL: tempURL)
                result = .success(())
            } catch {
                result = .failure(.writeFailed(error.localizedDescription))
            }
        } else {
            result = exportService.export(model: model, format: mappedFormat, to: tempURL)
        }

        exportProgress = 0.8

        switch result {
        case .success:
            exportedFileURL = tempURL
            showSuccessAlert = true
            exportProgress = 1.0
        case .failure(let error):
            logger.error("Export failed: \(error.localizedDescription)")
            exportError = "Error al exportar el modelo en formato \(selectedFormat.rawValue). Verifique que el modelo tenga geometria valida."
            exportProgress = 0.0
        }

        isExporting = false
    }

    func reset() {
        selectedFormat = .stl
        isExporting = false
        exportProgress = 0.0
        exportError = nil
        showSuccessAlert = false
        exportedFileURL = nil
        selectedModel = nil
    }
}
