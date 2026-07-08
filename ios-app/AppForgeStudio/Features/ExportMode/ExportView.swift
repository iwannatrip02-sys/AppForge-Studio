import SwiftUI
import UniformTypeIdentifiers
import QuickLook
import Metal
import MetalKit
import OSLog

private let logger = Logger(subsystem: "com.appforgestudio", category: "ExportView")

// MARK: - Quality/Resolution Options

enum ExportQuality: String, CaseIterable, Identifiable {
    case low = "Baja"
    case medium = "Media"
    case high = "Alta"

    var id: String { rawValue }

    var subdivisionLevels: Int {
        switch self {
        case .low: return 0
        case .medium: return 1
        case .high: return 2
        }
    }

    var icon: String {
        switch self {
        case .low: return "circle.grid.cross"
        case .medium: return "circle.grid.2x2"
        case .high: return "circle.grid.3x3"
        }
    }
}

// MARK: - Circular Progress View

struct CircularProgressView: View {
    @EnvironmentObject var themeManager: ThemeManager
    let progress: Double

    private var theme: AppTheme { themeManager.currentTheme }

    var body: some View {
        ZStack {
            Circle().stroke(theme.surfaceSecondary, lineWidth: 6)
            Circle().trim(from: 0, to: min(progress, 1.0))
                .stroke(theme.accent, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 1, dampingFraction: 0.75), value: progress)
            Text(String(format: "%d%%", Int(progress * 100)))
                .font(.caption.bold()).foregroundColor(theme.textPrimary)
        }.frame(width: 60, height: 60)
    }
}

// MARK: - Export View

struct ExportView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @ObservedObject var exportVM: ExportViewModel
    /// CanvasViewModel al que se añaden los modelos importados.
    /// Nil-safe: el botón funciona aunque no haya escena activa (informa al usuario).
    var canvasVM: CanvasViewModel? = nil

    private var theme: AppTheme { themeManager.currentTheme }
    @State private var showFileExporter = false
    @State private var exportFileName: String = "modelo"
    @State private var showProgress = false
    @State private var exportSuccess = false
    @State private var rotationAngle: Double = 0
    @State private var showARPreview = false
    @State private var arUSDZURL: URL?
    @State private var selectedQuality: ExportQuality = .medium
    @State private var selectedFormat: ExportViewModel.ExportFormat = .stl
    @State private var validationReport: String = ""
    @State private var showValidationWarning = false
    @State private var isExporting = false
    // Import
    @State private var showFileImporter = false
    @State private var importStatusMessage: String? = nil
    @State private var importHadError = false

    var body: some View {
        ZStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header with tap-to-rotate icon
                    headerSection

                    // Import de modelos externos
                    importSection

                    // Model preview
                    modelPreviewSection

                    // Format selection
                    formatSelectionSection

                    // Quality selection
                    qualitySelectionSection

                    // File name
                    fileNameSection

                    // Validation report (if issues found)
                    if showValidationWarning {
                        validationWarningSection
                    }

                    // Progress bar (real, from ExportViewModel)
                    if isExporting || exportVM.isExporting {
                        progressSection
                    }

                    // Export button
                    exportButtonSection

                    // AR QuickLook button (USDZ only)
                    if selectedFormat == .usdz {
                        arButtonSection
                    }

                    // Share button (appears after successful export)
                    if exportSuccess, let fileURL = exportVM.exportedFileURL {
                        shareButtonSection(fileURL: fileURL)
                    }
                }
                .padding(.bottom, 32)
            }

            // Success overlay
            if exportSuccess {
                successOverlay
            }
        }
        .animation(AppTheme.animSmooth, value:exportSuccess)
        .animation(AppTheme.animSmooth, value:isExporting)
        .fileExporter(
            isPresented: $showFileExporter,
            document: ExportFileDocument(url: exportVM.exportedFileURL),
            contentType: selectedFormat.utType,
            defaultFilename: "\(exportFileName).\(selectedFormat.fileExtension)"
        ) { result in
            if case .success = result {
                logger.info("File saved via fileExporter")
            }
        }
        .sheet(isPresented: $showARPreview) {
            if let url = arUSDZURL {
                ARQuickLookView(usdzURL: url)
                    .edgesIgnoringSafeArea(.all)
            }
        }
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: importFileTypes,
            allowsMultipleSelection: false
        ) { result in
            handleImportResult(result)
        }
        .onChange(of: exportVM.isExporting) { newValue in
            if !newValue && isExporting {
                // Export finished
                isExporting = false
                if exportVM.exportError == nil && exportVM.exportedFileURL != nil {
                    withAnimation(.easeOut(duration: 0.3)) {
                        exportSuccess = true
                    }
                }
            }
        }
        .onChange(of: exportVM.exportedFileURL) { url in
            if url != nil {
                withAnimation(.easeOut(duration: 0.3)) {
                    showFileExporter = true
                }
            }
        }
    }

    // MARK: - Tipos de archivo permitidos para importar

    /// Tipos UTType que ModelLoadService puede cargar vía MDLAsset.
    private var importFileTypes: [UTType] {
        [
            UTType(filenameExtension: "obj") ?? .data,
            UTType(filenameExtension: "stl") ?? .data,
            UTType(filenameExtension: "gltf") ?? .data,
            UTType(filenameExtension: "fbx") ?? .data,
            UTType(filenameExtension: "usdz") ?? .data,
        ]
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 8) {
            Image(systemName: "square.and.arrow.up.fill")
                .font(.system(size: 48)).foregroundColor(theme.accent)
                .rotationEffect(.degrees(rotationAngle))
                .onTapGesture {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.5)) { rotationAngle += 360 }
                }
            Text("Exportar Modelo").font(.title2.bold()).foregroundColor(theme.textPrimary)
            Text("Exporta tu modelo 3D para impresión 3D o CAD").font(.caption).foregroundColor(theme.textSecondary)
        }
        .padding(.top, 32)
    }

    // MARK: - Sección Importar

    /// Botón para importar un modelo externo (OBJ, STL, GLTF, FBX, USDZ).
    /// Usa fileImporter que maneja el security-scoped resource obligatorio en iOS.
    private var importSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Importar").font(.caption).foregroundColor(theme.textSecondary).padding(.leading, 4)

            Button(action: {
                HapticService.shared.light()
                importStatusMessage = nil
                importHadError = false
                showFileImporter = true
            }) {
                Label("Importar modelo 3D", systemImage: "square.and.arrow.down")
                    .font(.subheadline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(theme.surfaceSecondary)
                    .foregroundColor(theme.textPrimary)
                    .cornerRadius(theme.cornerRadiusSmall)
            }
            .buttonStyle(.plain)

            if let msg = importStatusMessage {
                Text(msg)
                    .font(.caption2)
                    .foregroundColor(importHadError ? theme.destructive : theme.success)
                    .padding(.horizontal, 4)
                    .transition(.opacity)
            }
        }
        .padding(.horizontal)
        .animation(AppTheme.animSmooth, value: importStatusMessage)
    }

    // MARK: - Manejador de importación

    /// Procesa el resultado de fileImporter: accede al recurso con security scope,
    /// carga la malla vía ModelLoadService y añade el Model a la escena activa.
    private func handleImportResult(_ result: Result<[URL], Error>) {
        switch result {
        case .failure(let error):
            importHadError = true
            importStatusMessage = "Error al seleccionar archivo: \(error.localizedDescription)"
            HapticService.shared.medium()

        case .success(let urls):
            guard let url = urls.first else { return }

            // fileImporter en iOS exige acceder al recurso con security scope
            let accessGranted = url.startAccessingSecurityScopedResource()
            defer {
                if accessGranted { url.stopAccessingSecurityScopedResource() }
            }

            guard let device = MTLCreateSystemDefaultDevice() else {
                importHadError = true
                importStatusMessage = "Error: Metal no disponible en este dispositivo"
                return
            }

            let loader = ModelLoadService(device: device)
            let loadResult = loader.loadModel(url: url)

            switch loadResult {
            case .success(let model):
                if let cv = canvasVM {
                    cv.scene.addModel(model)
                    cv.objectWillChange.send()
                    exportVM.selectedModel = model
                    importHadError = false
                    importStatusMessage = "Modelo '\(url.lastPathComponent)' importado y añadido a la escena"
                } else {
                    // Sin canvasVM disponible: informar pero no fallar
                    exportVM.selectedModel = model
                    importHadError = false
                    importStatusMessage = "Modelo '\(url.lastPathComponent)' cargado (sin escena activa para añadirlo)"
                }
                HapticService.shared.medium()

            case .failure(let loadError):
                importHadError = true
                switch loadError {
                case .fileNotFound(let name):
                    importStatusMessage = "Archivo no encontrado: \(name)"
                case .invalidFormat(let msg):
                    importStatusMessage = "Formato no soportado: \(msg)"
                case .meshCreationFailed(let msg):
                    importStatusMessage = "Error al crear la malla: \(msg)"
                }
                HapticService.shared.medium()
            }
        }
    }

    // MARK: - Model Preview

    private var modelPreviewSection: some View {
        VStack(spacing: 8) {
            if let model = exportVM.selectedModel {
                ZStack {
                    RoundedRectangle(cornerRadius: theme.cornerRadiusLarge).fill(theme.surfaceSecondary).frame(height: 180)
                    Image(systemName: "cube.transparent").font(.system(size: 64)).foregroundColor(theme.accent.opacity(0.3))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(model.name).font(.subheadline.bold()).foregroundColor(theme.textPrimary)
                        let triCount = model.meshes.reduce(0) { $0 + $1.indices.count / 3 }
                        Text("\(triCount) triángulos").font(.caption2).foregroundColor(theme.textSecondary)
                        let vertCount = model.meshes.reduce(0) { $0 + $1.vertices.count }
                        Text("\(vertCount) vértices").font(.caption2).foregroundColor(theme.textSecondary)
                    }
                    .padding(8).background(theme.surface).cornerRadius(theme.cornerRadiusSmall)
                }
            } else {
                RoundedRectangle(cornerRadius: theme.cornerRadiusLarge).fill(theme.surfaceSecondary).frame(height: 180)
                    .overlay(
                        VStack(spacing: 8) {
                            Image(systemName: "cube.transparent").font(.system(size: 40)).foregroundColor(theme.textSecondary.opacity(0.3))
                            Text("Sin modelo seleccionado").font(.caption).foregroundColor(theme.textSecondary)
                        }
                    )
            }
        }.padding(.horizontal)
    }

    // MARK: - Format Selection

    private var formatSelectionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Formato").font(.caption).foregroundColor(theme.textSecondary).padding(.leading, 4)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                ForEach(ExportViewModel.ExportFormat.allCases) { fmt in
                    Button(action: {
                        withAnimation(AppTheme.animSnappy) {
                            selectedFormat = fmt
                            exportVM.selectedFormat = fmt
                        }
                    }) {
                        VStack(spacing: 4) {
                            Image(systemName: fmt.icon)
                                .font(.system(size: 18))
                            Text(fmt.rawValue)
                                .font(.caption.bold())
                            Text(fmt.description)
                                .font(.system(size: 8))
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(selectedFormat == fmt ? theme.accent : theme.surfaceSecondary)
                        .foregroundColor(selectedFormat == fmt ? .white : theme.textPrimary)
                        .cornerRadius(theme.cornerRadiusSmall)
                    }
                }
            }
        }.padding(.horizontal)
    }

    // MARK: - Quality Selection

    private var qualitySelectionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Calidad").font(.caption).foregroundColor(theme.textSecondary).padding(.leading, 4)

            HStack(spacing: 8) {
                ForEach(ExportQuality.allCases) { quality in
                    Button(action: {
                        withAnimation(AppTheme.animSnappy) {
                            selectedQuality = quality
                        }
                    }) {
                        VStack(spacing: 4) {
                            Image(systemName: quality.icon)
                                .font(.system(size: 16))
                            Text(quality.rawValue)
                                .font(.caption2)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(selectedQuality == quality ? theme.accent.opacity(0.3) : theme.surfaceSecondary)
                        .foregroundColor(selectedQuality == quality ? theme.accent : theme.textPrimary)
                        .cornerRadius(theme.cornerRadiusSmall)
                        .overlay(
                            RoundedRectangle(cornerRadius: theme.cornerRadiusSmall)
                                .stroke(selectedQuality == quality ? theme.accent : Color.clear, lineWidth: 1.5)
                        )
                    }
                }
            }
        }.padding(.horizontal)
    }

    // MARK: - File Name

    private var fileNameSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Nombre del archivo").font(.caption).foregroundColor(theme.textSecondary).padding(.leading, 4)
            TextField("modelo", text: $exportFileName)
                .textFieldStyle(.plain).font(.body).foregroundColor(theme.textPrimary)
                .padding(12).background(theme.surfaceSecondary).cornerRadius(theme.cornerRadiusSmall)
                .overlay(
                    HStack {
                        Spacer()
                        Text(".\(selectedFormat.fileExtension)")
                            .font(.caption)
                            .foregroundColor(theme.textSecondary)
                            .padding(.trailing, 12)
                    }
                )
        }.padding(.horizontal)
    }

    // MARK: - Validation Warning

    private var validationWarningSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(theme.warning)
                Text("Advertencias de validación")
                    .font(.caption.bold())
                    .foregroundColor(theme.warning)
                Spacer()
                Button("Descartar") {
                    withAnimation { showValidationWarning = false }
                }
                .font(.caption2)
            }
            Text(validationReport)
                .font(.caption2)
                .foregroundColor(theme.textSecondary)
                .lineLimit(6)
        }
        .padding(12)
        .background(theme.warning.opacity(0.1))
        .cornerRadius(theme.cornerRadiusSmall)
        .padding(.horizontal)
    }

    // MARK: - Progress

    private var progressSection: some View {
        HStack(spacing: 16) {
            CircularProgressView(progress: Double(exportVM.exportProgress))
            VStack(alignment: .leading, spacing: 4) {
                Text(exportProgressLabel).font(.subheadline).foregroundColor(theme.textPrimary)
                Text(String(format: "%.0f%% completado", exportVM.exportProgress * 100))
                    .font(.caption).foregroundColor(theme.textSecondary)
            }
            Spacer()
        }
        .padding(.horizontal)
        .transition(.scale.combined(with: .opacity))
    }

    private var exportProgressLabel: String {
        let p = exportVM.exportProgress
        if p < 0.1 { return "Validando malla..."
        } else if p < 0.5 { return "Procesando geometría..."
        } else if p < 0.9 { return "Escribiendo archivo..."
        } else { return "Finalizando..."
        }
    }

    // MARK: - Export Button

    private var exportButtonSection: some View {
        Button(action: performExport) {
            HStack {
                if isExporting || exportVM.isExporting {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    Text("Exportando...")
                        .font(.headline)
                } else {
                    Image(systemName: "square.and.arrow.up")
                    Text("Exportar \(selectedFormat.rawValue)")
                        .font(.headline)
                }
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity).padding(.vertical, 14)
            .background((isExporting || exportVM.isExporting) ? theme.accent.opacity(0.6) : theme.accent)
            .cornerRadius(theme.cornerRadiusMedium)
        }
        .padding(.horizontal)
        .disabled(isExporting || exportVM.isExporting || exportVM.selectedModel == nil)
        .opacity(exportVM.selectedModel == nil ? 0.5 : 1.0)
    }

    // MARK: - AR Button

    private var arButtonSection: some View {
        Button(action: {
            if let model = exportVM.selectedModel {
                if let url = exportVM.prepareUSDZForAR(model: model, exportService: exportVM.exportService) {
                    arUSDZURL = url
                    showARPreview = true
                }
            }
        }) {
            Label("Ver en AR", systemImage: "arkit")
                .font(.headline).foregroundColor(.white)
                .frame(maxWidth: .infinity).padding(.vertical, 14)
                .background(theme.success).cornerRadius(theme.cornerRadiusMedium)
        }.padding(.horizontal)
    }

    // MARK: - Share Button

    private func shareButtonSection(fileURL: URL) -> some View {
        VStack(spacing: 8) {
            Divider().padding(.horizontal)

            if #available(iOS 16.0, *) {
                ShareLink(item: fileURL) {
                    Label("Compartir archivo", systemImage: "square.and.arrow.up")
                        .font(.headline).foregroundColor(.white)
                        .frame(maxWidth: .infinity).padding(.vertical, 14)
                        .background(theme.accent).cornerRadius(theme.cornerRadiusMedium)
                }
                .padding(.horizontal)

                // Also offer "Save to Files" via fileExporter
                Button(action: { showFileExporter = true }) {
                    Label("Guardar en Archivos", systemImage: "folder")
                        .font(.subheadline).foregroundColor(theme.textPrimary)
                        .frame(maxWidth: .infinity).padding(.vertical, 10)
                        .background(theme.surfaceSecondary).cornerRadius(theme.cornerRadiusSmall)
                }
                .padding(.horizontal)
            } else {
                Button(action: { showFileExporter = true }) {
                    Label("Compartir / Guardar", systemImage: "square.and.arrow.up")
                        .font(.headline).foregroundColor(.white)
                        .frame(maxWidth: .infinity).padding(.vertical, 14)
                        .background(theme.accent).cornerRadius(theme.cornerRadiusMedium)
                }
                .padding(.horizontal)
            }
        }
    }

    // MARK: - Success Overlay

    private var successOverlay: some View {
        ZStack {
            theme.surface.edgesIgnoringSafeArea(.all).transition(.opacity)
            VStack(spacing: 16) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 64)).foregroundColor(theme.success)
                    .scaleEffect(exportSuccess ? 1 : 0)
                    .animation(AppTheme.animSnappy, value: exportSuccess)
                Text("Exportación exitosa").font(.title2.bold()).foregroundColor(theme.textPrimary)
                Text("\(exportFileName).\(selectedFormat.fileExtension)")
                    .font(.caption).foregroundColor(theme.textSecondary)
                Button("Cerrar") {
                    withAnimation(AppTheme.animSmooth) {
                        exportSuccess = false
                        exportVM.reset()
                    }
                }
                .font(.headline).foregroundColor(theme.accent)
                .padding(.horizontal, 32).padding(.vertical, 12)
                .background(theme.accent.opacity(0.2)).cornerRadius(theme.cornerRadiusSmall)
            }.transition(.scale.combined(with: .opacity))
        }
    }

    // MARK: - Export Action

    private func performExport() {
        guard exportVM.selectedModel != nil else { return }

        isExporting = true
        exportSuccess = false
        showValidationWarning = false
        validationReport = ""
        exportVM.exportError = nil

        // Run validation before export
        if let model = exportVM.selectedModel, let mesh = model.meshes.first {
            let report = ExportService.validateMeshForExport(mesh, name: model.name)
            if !report.issues.isEmpty {
                validationReport = report.description
                withAnimation { showValidationWarning = true }
                logger.info("Pre-export validation: \(report.description)")
            }
        }

        // Fire real async export via ExportViewModel
        Task {
            await exportVM.exportModel(fileName: exportFileName)
            await MainActor.run {
                isExporting = false
                if exportVM.exportError != nil {
                    logger.error("Export failed: \(exportVM.exportError ?? "unknown")")
                } else if exportVM.exportedFileURL != nil {
                    withAnimation(.easeOut(duration: 0.3)) {
                        exportSuccess = true
                    }
                }
            }
        }
    }
}

// MARK: - FileDocument wrapper for fileExporter

struct ExportFileDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.data] }

    private let data: Data

    init(url: URL?) {
        self.data = (url.flatMap { try? Data(contentsOf: $0) }) ?? Data()
    }

    init(configuration: ReadConfiguration) throws {
        self.data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
