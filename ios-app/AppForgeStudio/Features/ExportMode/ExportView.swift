import SwiftUI
import UniformTypeIdentifiers

struct ExportView: View {
    @ObservedObject var exportVM: ExportViewModel
    @State private var showFileExporter = false
    @State private var exportFileName: String = "modelo"
    @State private var showProgress = false
    
    var body: some View {
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 8) {
                Image(systemName: "square.and.arrow.up.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.accentColor)
                Text("Exportar Modelo")
                    .font(.title2.bold())
                    .foregroundColor(.white)
                Text("Exporta tu modelo 3D para impresion 3D o CAD")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            .padding(.top, 32)
            .transition(.opacity.combined(with: .scale))
            
            // Model preview (if selected)
            if let model = exportVM.selectedModel {
                HStack(spacing: 12) {
                    Image(systemName: "cube.fill")
                        .font(.title2)
                        .foregroundColor(.accentColor)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(model.name ?? "Modelo")
                            .font(.subheadline.bold())
                            .foregroundColor(.white)
                        Text("\(model.triangleCount ?? 0) triangulos")
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
                    Spacer()
                }
                .padding(12)
                .background(Color.gray.opacity(0.15))
                .cornerRadius(10)
                .padding(.horizontal)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
            
            // Format selection
            VStack(alignment: .leading, spacing: 12) {
                Text("Formato de archivo")
                    .font(.headline)
                    .foregroundColor(.white)
                
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 140))], spacing: 12) {
                    ForEach(ExportViewModel.ExportFormat.allCases) { format in
                        Button(action: {
                            withAnimation(.spring(response: 0.3)) {
                                exportVM.selectedFormat = format
                            }
                        }) {
                            VStack(spacing: 6) {
                                Image(systemName: format.icon)
                                    .font(.title2)
                                Text(format.rawValue)
                                    .font(.caption.bold())
                                Text(format.description)
                                    .font(.caption2)
                                    .foregroundColor(.gray)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(12)
                            .background(exportVM.selectedFormat == format ?
                                        Color.accentColor.opacity(0.3) :
                                        Color.gray.opacity(0.1))
                            .cornerRadius(10)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(exportVM.selectedFormat == format ? Color.accentColor : Color.clear, lineWidth: 2)
                            )
                        }
                    }
                }
            }
            .padding(.horizontal)
            
            // File name
            VStack(alignment: .leading, spacing: 8) {
                Text("Nombre del archivo")
                    .font(.headline)
                    .foregroundColor(.white)
                TextField("modelo", text: $exportFileName)
                    .textFieldStyle(.roundedBorder)
                    .padding(.horizontal)
            }
            .padding(.horizontal)
            
            // Progress bar
            if exportVM.isExporting || showProgress {
                VStack(spacing: 8) {
                    ProgressView(value: Double(exportVM.exportProgress), total: 1.0)
                        .progressViewStyle(LinearProgressViewStyle(tint: .accentColor))
                        .animation(.easeInOut(duration: 0.3), value: exportVM.exportProgress)
                    Text("Exportando... \(Int(exportVM.exportProgress * 100))%")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                .padding(.horizontal)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
            
            // Error message
            if let error = exportVM.exportError {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                }
                .padding(10)
                .background(Color.red.opacity(0.1))
                .cornerRadius(8)
                .padding(.horizontal)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
            
            // Success alert
            if exportVM.showSuccessAlert {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Exportacion completada")
                        .font(.caption)
                        .foregroundColor(.green)
                }
                .padding(10)
                .background(Color.green.opacity(0.1))
                .cornerRadius(8)
                .padding(.horizontal)
                .transition(.opacity.combined(with: .scale))
            }
            
            Spacer()
            
            // Export button
            Button(action: {
                withAnimation {
                    showProgress = true
                }
                Task {
                    await exportVM.exportModel(fileName: exportFileName)
                }
            }) {
                HStack {
                    if exportVM.isExporting {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    }
                    Text(exportVM.isExporting ? "Exportando..." : "Exportar")
                        .font(.headline)
                    if !exportVM.isExporting {
                        Image(systemName: "arrow.up.doc.fill")
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(exportVM.isExporting ? Color.gray : Color.accentColor)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .disabled(exportVM.isExporting || exportVM.selectedModel == nil)
            .padding(.horizontal)
            .padding(.bottom, 32)
        }
        .background(Color.black.edgesIgnoringSafeArea(.all))
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: exportVM.exportProgress)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: exportVM.isExporting)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: exportVM.exportError != nil)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: exportVM.showSuccessAlert)
        .fileExporter(
            isPresented: $showFileExporter,
            document: exportVM.exportedFileURL.map { url in
                FileDocument(url: url)
            },
            contentType: exportVM.selectedFormat.utType,
            defaultFilename: exportFileName
        ) { result in
            switch result {
            case .success(let url):
                print("Exportado a: \(url)")
            case .failure(let error):
                exportVM.exportError = error.localizedDescription
            }
        }
    }
}

// MARK: - FileDocument wrapper
struct FileDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.data] }
    var url: URL
    
    init(url: URL) {
        self.url = url
    }
    
    init(configuration: ReadConfiguration) throws {
        fatalError("Not implemented")
    }
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(url: url)
    }
}