import SwiftUI
import UniformTypeIdentifiers
import QuickLook
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
                .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 1, dampingFraction: 0.75), value: progress)
            Text(String(format: "%d%%", Int(progress * 100)))
                .font(.caption.bold()).foregroundColor(theme.textPrimary)
        }.frame(width: 60, height: 60)
    }
}

// MARK: - Confetti View (success animation)

struct ConfettiView: View {
    @State private var particles: [(offset: CGSize, opacity: Double, color: Color)] = []
    var body: some View {
        GeometryReader { geometry in
            ForEach(0..<particles.count, id: \.self) { i in
                Circle().fill(particles[i].color).frame(width: 8, height: 8)
                    .offset(particles[i].offset).opacity(particles[i].opacity)
            }
        }.onAppear {
            let colors: [Color] = [.accentColor, .green, .blue, .orange, .pink, .purple]
            var temp: [(CGSize, Double, Color)] = []
            for _ in 0..<30 {
                let x = CGFloat.random(in: -150...150)
                let y = CGFloat.random(in: -200...50)
                let op = Double.random(in: 0.6...1.0)
                let col = colors.randomElement() ?? .accentColor
                temp.append((CGSize(width: x, height: y), op, col))
            }
            particles = temp
            withAnimation(.easeOut(duration: 2.0)) {
                particles = particles.map { (CGSize(width: $0.offset.width * 1.5, height: $0.offset.height + 100), 0, $0.color) }
            }
        }
    }
}

// MARK: - Export View

struct ExportView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @ObservedObject var exportVM: ExportViewModel

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

    var body: some View {
        ZStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header with tap-to-rotate icon
                    headerSection

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
        .animation(.easeInOut(duration: 0.3), value: exportSuccess)
        .animation(.easeInOut(duration: 0.3), value: isExporting)
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

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 8) {
            Image(systemName: "square.and.arrow.up.fill")
                .font(.system(size: 48)).foregroundColor(.accentColor)
                .rotationEffect(.degrees(rotationAngle))
                .onTapGesture {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.5)) { rotationAngle += 360 }
                }
            Text("Exportar Modelo").font(.title2.bold()).foregroundColor(theme.textPrimary)
            Text("Exporta tu modelo 3D para impresión 3D o CAD").font(.caption).foregroundColor(theme.textSecondary)
        }
        .padding(.top, 32)
    }

    // MARK: - Model Preview

    private var modelPreviewSection: some View {
        VStack(spacing: 8) {
            if let model = exportVM.selectedModel {
                ZStack {
                    RoundedRectangle(cornerRadius: 12).fill(theme.surfaceSecondary).frame(height: 180)
                    Image(systemName: "cube.transparent").font(.system(size: 64)).foregroundColor(.accentColor.opacity(0.3))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(model.name).font(.subheadline.bold()).foregroundColor(theme.textPrimary)
                        let triCount = model.meshes.reduce(0) { $0 + $1.indices.count / 3 }
                        Text("\(triCount) triángulos").font(.caption2).foregroundColor(theme.textSecondary)
                        let vertCount = model.meshes.reduce(0) { $0 + $1.vertices.count }
                        Text("\(vertCount) vértices").font(.caption2).foregroundColor(theme.textSecondary)
                    }
                    .padding(8).background(theme.surface).cornerRadius(8)
                }
            } else {
                RoundedRectangle(cornerRadius: 12).fill(theme.surfaceSecondary).frame(height: 180)
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
                        withAnimation(.easeInOut(duration: 0.2)) {
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
                        .background(selectedFormat == fmt ? Color.accentColor : theme.surfaceSecondary)
                        .foregroundColor(selectedFormat == fmt ? .white : theme.textPrimary)
                        .cornerRadius(10)
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
                        withAnimation(.easeInOut(duration: 0.2)) {
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
                        .background(selectedQuality == quality ? Color.accentColor.opacity(0.3) : theme.surfaceSecondary)
                        .foregroundColor(selectedQuality == quality ? .accentColor : theme.textPrimary)
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(selectedQuality == quality ? Color.accentColor : Color.clear, lineWidth: 1.5)
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
                .padding(12).background(theme.surfaceSecondary).cornerRadius(10)
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
                    .foregroundColor(.orange)
                Text("Advertencias de validación")
                    .font(.caption.bold())
                    .foregroundColor(.orange)
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
        .background(Color.orange.opacity(0.1))
        .cornerRadius(10)
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
            .background((isExporting || exportVM.isExporting) ? Color.accentColor.opacity(0.6) : Color.accentColor)
            .cornerRadius(12)
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
                .background(Color.green).cornerRadius(12)
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
                        .background(Color.blue).cornerRadius(12)
                }
                .padding(.horizontal)

                // Also offer "Save to Files" via fileExporter
                Button(action: { showFileExporter = true }) {
                    Label("Guardar en Archivos", systemImage: "folder")
                        .font(.subheadline).foregroundColor(theme.textPrimary)
                        .frame(maxWidth: .infinity).padding(.vertical, 10)
                        .background(theme.surfaceSecondary).cornerRadius(10)
                }
                .padding(.horizontal)
            } else {
                Button(action: { showFileExporter = true }) {
                    Label("Compartir / Guardar", systemImage: "square.and.arrow.up")
                        .font(.headline).foregroundColor(.white)
                        .frame(maxWidth: .infinity).padding(.vertical, 14)
                        .background(Color.blue).cornerRadius(12)
                }
                .padding(.horizontal)
            }
        }
    }

    // MARK: - Success Overlay

    private var successOverlay: some View {
        ZStack {
            theme.surface.edgesIgnoringSafeArea(.all).transition(.opacity)
            ConfettiView().transition(.opacity)
            VStack(spacing: 16) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 64)).foregroundColor(.green)
                    .scaleEffect(exportSuccess ? 1 : 0)
                    .animation(.spring(response: 0.4, dampingFraction: 0.5), value: exportSuccess)
                Text("Exportación exitosa").font(.title2.bold()).foregroundColor(theme.textPrimary)
                Text("\(exportFileName).\(selectedFormat.fileExtension)")
                    .font(.caption).foregroundColor(theme.textSecondary)
                Button("Cerrar") {
                    withAnimation(.easeOut(duration: 0.3)) {
                        exportSuccess = false
                        exportVM.reset()
                    }
                }
                .font(.headline).foregroundColor(.accentColor)
                .padding(.horizontal, 32).padding(.vertical, 12)
                .background(Color.accentColor.opacity(0.2)).cornerRadius(10)
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
