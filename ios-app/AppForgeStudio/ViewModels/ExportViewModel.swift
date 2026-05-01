import SwiftUI

class ExportViewModel: ObservableObject {
    @Published var isExporting = false
    @Published var progress: Double = 0.0
    @Published var exportMessage: String?
    @Published var exportSuccess = false
    
    func exportSTL(model: Model, format: ExportFormat) {
        isExporting = true
        progress = 0.0
        exportMessage = nil
        exportSuccess = false
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation(.easeInOut(duration: 1.5)) {
                self.progress = 1.0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                self.isExporting = false
                self.exportSuccess = true
                self.exportMessage = "Model exported as \(format.rawValue)"
            }
        }
    }
}

enum ExportFormat: String {
    case stl = "STL"
    case obj = "OBJ"
    case usdz = "USDZ"
    case step = "STEP"
}
