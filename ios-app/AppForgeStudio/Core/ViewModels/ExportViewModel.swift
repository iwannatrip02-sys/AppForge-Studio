import Foundation
import SwiftUI
import UniformTypeIdentifiers

@MainActor
class ExportViewModel: ObservableObject {
    enum ExportFormat: String, CaseIterable, Identifiable {
        case obj = "OBJ"
        case stl = "STL"
        case step = "STEP"
        case usdz = "USDZ"
        var id: String { rawValue }
        var fileExtension: String {
            switch self {
            case .obj: return "obj"
            case .stl: return "stl"
            case .step: return "step"
            case .usdz: return "usdz"
            }
        }
        var description: String {
            switch self {
            case .obj: return "Wavefront OBJ"
            case .stl: return "Estereolitografia"
            case .step: return "STEP CAD"
            case .usdz: return "Universal Scene Description"
            }
        }
        var icon: String {
            switch self {
            case .stl: return "cube.fill"
            case .obj: return "doc.text.fill"
            case .step: return "gearshape.fill"
            case .usdz: return "arkit"
            }
        }
        var utType: UTType {
            switch self {
            case .obj: return UTType(filenameExtension: "obj") ?? .data
            case .stl: return UTType(filenameExtension: "stl") ?? .data
            case .step: return UTType(filenameExtension: "step") ?? .data
            case .usdz: return UTType(filenameExtension: "usdz") ?? .data
            }
        }
    }
    
    @Published var selectedFormat: ExportFormat = .stl
    @Published var isExporting = false
    @Published var exportProgress: Float = 0.0
    @Published var exportError: String?
    @Published var showSuccessAlert = false
    @Published var exportedFileURL: URL?
    
    let exportService: ExportService
    
    init(exportService: ExportService) {
        self.exportService = exportService
    }
    
    func exportModel(_ model: Model, fileName: String) async {
        isExporting = true
        exportError = nil
        exportProgress = 0.0
        exportedFileURL = nil
        
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(fileName)
            .appendingPathExtension(selectedFormat.fileExtension)
        
        exportProgress = 0.3
        
        let success: Bool
        switch selectedFormat {
        case .obj:
            success = exportService.exportToOBJ(model: model, url: tempURL)
        case .stl:
            success = exportService.exportToSTL(model: model, url: tempURL)
        case .step:
            success = exportService.exportToSTEP(model: model, url: tempURL)
        case .usdz:
            success = exportService.exportToUSDZ(model: model, url: tempURL)
        }
        
        exportProgress = 0.8
        
        if success {
            exportedFileURL = tempURL
            showSuccessAlert = true
            exportProgress = 1.0
        } else {
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
    }
}
