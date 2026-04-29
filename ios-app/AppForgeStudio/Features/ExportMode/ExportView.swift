import SwiftUI
import UniformTypeIdentifiers

struct ExportView: View {
    let model: Model
    @ObservedObject var exportVM: ExportViewModel
    @State private var showFileExporter = false
    @State private var exportFileName: String = "modelo"
    
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
            
            // Selector de formato
            VStack(alignment: .leading, spacing: 12) {
                Text("Formato de archivo")
                    .font(.headline)
                    .foregroundColor(.white)
                
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 140))], spacing: 12) {
                    ForEach(ExportViewModel.ExportFormat.allCases) { format in
                        Button(action: { exportVM.selectedFormat = format }) {
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
                                        Color.gray.opacity(0.15))
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(exportVM.selectedFormat == format ? Color.accentColor : Color.clear, lineWidth: 2)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 24)
            
            // Nombre de archivo
            VStack(alignment: .leading, spacing: 8) {
                Text("Nombre del archivo")
                    .font(.headline)
                    .foregroundColor(.white)
                TextField("nombre-del-modelo", text: $exportFileName)
                    .textFieldStyle(.roundedBorder)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                Text(".\(exportVM.selectedFormat.fileExtension)")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            .padding(.horizontal, 24)
            
            Spacer()
            
            // Progress bar
            if exportVM.isExporting {
                VStack(spacing: 8) {
                    ProgressView(value: exportVM.exportProgress)
                        .progressViewStyle(.linear)
                        .tint(.accentColor)
                    Text("Exportando... \(Int(exportVM.exportProgress * 100))%")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                .padding(.horizontal, 24)
            }
            
            // Boton exportar
            Button(action: {
                Task {
                    await exportVM.exportModel(model, fileName: exportFileName)
                    if exportVM.exportedFileURL != nil {
                        showFileExporter = true
                    }
                }
            }) {
                HStack {
                    Image(systemName: "square.and.arrow.up")
                    Text("Exportar")
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(exportVM.isExporting ? Color.gray : Color.accentColor)
                .cornerRadius(12)
            }
            .disabled(exportVM.isExporting)
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
        .background(Color.black.opacity(0.9))
        .alert("Exportacion exitosa", isPresented: $exportVM.showSuccessAlert) {
            Button("Compartir") { showFileExporter = true }
            Button("Cerrar", role: .cancel) { exportVM.reset() }
        } message: {
            Text("El modelo se exporto correctamente en formato \(exportVM.selectedFormat.rawValue).")
        }
        .alert("Error de exportacion", isPresented: Binding<Bool>(
            get: { exportVM.exportError != nil },
            set: { if !$0 { exportVM.exportError = nil } }
        )) {
            Button("Cerrar", role: .cancel) { exportVM.exportError = nil }
        } message: {
            Text(exportVM.exportError ?? "Error desconocido")
        }
        .fileExporter(
            isPresented: $showFileExporter,
            document: exportVM.exportedFileURL != nil ?
                ExportFileData(url: exportVM.exportedFileURL!) : nil,
            contentType: exportVM.selectedFormat.utType,
            defaultFilename: exportFileName + "." + exportVM.selectedFormat.fileExtension
        ) { result in
            switch result {
            case .success:
                exportVM.reset()
            case .failure(let error):
                exportVM.exportError = "Error al guardar: \(error.localizedDescription)"
            }
        }
    }
}

// Helper para fileExporter
struct ExportFileData: FileDocument {
    let url: URL
    
    static var readableContentTypes: [UTType] { [.data] }
    
    init(url: URL) {
        self.url = url
    }
    
    init(configuration: ReadConfiguration) throws {
        throw CocoaError(.fileReadUnknown)
    }
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(url: url)
    }
}
