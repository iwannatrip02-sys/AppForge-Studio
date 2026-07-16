import SwiftUI
import QuickLook
import OSLog

private let logger = Logger(subsystem: "com.appforgestudio", category: "ARQuickLook")

struct ARQuickLookView: UIViewControllerRepresentable {
    let usdzURL: URL
    
    func makeUIViewController(context: Context) -> QLPreviewController {
        let controller = QLPreviewController()
        controller.dataSource = context.coordinator
        return controller
    }
    
    func updateUIViewController(_ uiViewController: QLPreviewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(url: usdzURL)
    }
    
    class Coordinator: NSObject, QLPreviewControllerDataSource {
        let url: URL
        
        init(url: URL) {
            self.url = url
        }
        
        func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
            return 1
        }
        
        func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
            return url as NSURL
        }
    }
}

// MARK: - View Model extension for AR preview
@MainActor
extension ExportViewModel {
    func prepareUSDZForAR(model: Model, exportService: ExportService) -> URL? {
        prepareUSDZForAR(models: [model], exportService: exportService)
    }

    /// AR de ESCENA COMPLETA: todos los cuerpos con sus materiales PBR reales
    /// (Shapr3D solo muestra un cuerpo a la vez en AR).
    func prepareUSDZForAR(models: [Model], exportService: ExportService) -> URL? {
        let tempDir = FileManager.default.temporaryDirectory
        let usdzURL = tempDir.appendingPathComponent("ar_preview_\(UUID().uuidString.prefix(8)).usdz")
        do {
            try exportService.exportUSDZScene(models: models, to: usdzURL)
            logger.info("USDZ prepared for AR at \(usdzURL.path)")
            return usdzURL
        } catch {
            logger.error("Failed to prepare USDZ for AR: \(error.localizedDescription)")
            return nil
        }
    }
}
