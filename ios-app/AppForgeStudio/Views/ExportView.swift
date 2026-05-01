import SwiftUI
import UniformTypeIdentifiers

struct ExportView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @State private var selectedFormat: ExportFormat = .obj
    @State private var isExporting = false
    @State private var exportResult: ExportResult?
    @State private var showFilePicker = false
    let model: Model
    let exportService: ExportService
    
    enum ExportFormat: String, CaseIterable, Identifiable {
        case obj, stl, usdz, step, gltf
        var id: String { rawValue }
        var fileExtension: String {
            switch self {
            case .obj: return "obj"
            case .stl: return "stl"
            case .usdz: return "usdz"
            case .step: return "step"
            case .gltf: return "gltf"
            }
        }
        var utType: UTType {
            switch self {
            case .obj: return UTType(filenameExtension: "obj") ?? .data
            case .stl: return UTType(filenameExtension: "stl") ?? .data
            case .usdz: return UTType(filenameExtension: "usdz") ?? .data
            case .step: return UTType(filenameExtension: "step") ?? .data
            case .gltf: return UTType(filenameExtension: "gltf") ?? .data
            }
        }
    }
    
    enum ExportResult {
        case success(URL)
        case failure(String)
    }
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Export \(model.name)")
                .font(.title2).bold()
                .foregroundColor(themeManager.currentTheme.textPrimary)
            
            Picker("Format", selection: $selectedFormat) {
                ForEach(ExportFormat.allCases) { fmt in
                    Text(fmt.rawValue.uppercased()).tag(fmt)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            
            if isExporting {
                ProgressView("Exporting...")
                    .progressViewStyle(.circular)
                    .scaleEffect(1.5)
            }
            
            Button(action: startExport) {
                Label("Export", systemImage: "square.and.arrow.up")
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.borderedProminent)
            .disabled(isExporting)
            .padding(.horizontal)
            
            if let result = exportResult {
                switch result {
                case .success(let url):
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Saved to\n\(url.lastPathComponent)")
                            .font(.caption)
                    }
                    .padding()
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(8)
                case .failure(let error):
                    HStack {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.red)
                        Text(error).font(.caption)
                    }
                    .padding()
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(8)
                }
            }
        }
        .padding()
        .fileExporter(isPresented: $showFilePicker,
                      document: model,
                      contentType: selectedFormat.utType,
                      defaultFilename: model.name + "." + selectedFormat.fileExtension) { result in
            switch result {
            case .success(let url):
                performExport(to: url)
            case .failure:
                exportResult = .failure("File selection cancelled")
            }
        }
    }
    
    private func startExport() {
        showFilePicker = true
    }
    
    private func performExport(to url: URL) {
        isExporting = true
        exportResult = nil
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                switch selectedFormat {
                case .obj: try exportService.exportToOBJ(model: model, url: url)
                case .stl: try exportService.exportToSTL(model: model, url: url)
                case .usdz: try exportService.exportToUSDZ(model: model, url: url)
                case .step: try exportService.exportToSTEP(model: model, url: url)
                case .gltf: try exportService.exportToGLTF(model: model, url: url)
                }
                DispatchQueue.main.async {
                    isExporting = false
                    exportResult = .success(url)
                }
            } catch {
                DispatchQueue.main.async {
                    isExporting = false
                    exportResult = .failure(error.localizedDescription)
                }
            }
        }
    }
}
