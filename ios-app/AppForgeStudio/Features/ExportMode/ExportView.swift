import SwiftUI
import UniformTypeIdentifiers

struct ExportView: View {
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
                            .background(exportVM.selectedFormat == format ? Color.accentColor.opacity(0.2) : Color.gray.opacity(0.1))
                            .cornerRadius(10)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 24)
            
            // Nombre del archivo
            HStack {
                Text("Nombre:")
                    .foregroundColor(.gray)
                TextField("Nombre del archivo", text: $exportFileName)
                    .textFieldStyle(.roundedBorder)
                    .foregroundColor(.white)
                Text("." + exportVM.selectedFormat.fileExtension)
                    .foregroundColor(.gray)
            }
            .padding(.horizontal, 24)
            
            // Info del modelo
            if let model = exportVM.selectedModel {
                HStack {
                    Text(model.name)
                        .foregroundColor(.white)
                    Text("\(model.meshes.count) mallas")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            
            Spacer()
            
            // Boton exportar
            Button(action: { showFileExporter = true }) {
                HStack {
                    if exportVM.isExporting {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "square.and.arrow.up")
                    }
                    Text(exportVM.isExporting ? "Exportando..." : "Exportar")
                }
                .frame(maxWidth: .infinity)
                .padding(16)
                .background(exportVM.isExporting ? Color.gray : Color.accentColor)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .disabled(exportVM.isExporting || exportVM.selectedModel == nil)
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
        .background(Color.black.opacity(0.9))
        .fileExporter(isPresented: $showFileExporter,
                      document: exportVM.selectedModel.map { ExportDocument(model: $0) },
                      contentType: exportVM.selectedFormat.utType,
                      defaultFilename: exportFileName + "." + exportVM.selectedFormat.fileExtension) { result in
            switch result {
            case .success(let url):
                exportVM.exportedFileURL = url
                exportVM.showSuccessAlert = true
            case .failure(let error):
                exportVM.exportError = error.localizedDescription
            }
        }
        .alert("Exportado exitosamente", isPresented: $exportVM.showSuccessAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Archivo guardado en \(exportVM.exportedFileURL?.lastPathComponent ?? "")")
        }
        .alert("Error al exportar", isPresented: .constant(exportVM.exportError != nil)) {
            Button("OK", role: .cancel) { exportVM.exportError = nil }
        } message: {
            Text(exportVM.exportError ?? "")
        }
    }
}
