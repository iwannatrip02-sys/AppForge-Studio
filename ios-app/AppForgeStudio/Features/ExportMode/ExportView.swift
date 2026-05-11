import SwiftUI
import UniformTypeIdentifiers
import QuickLook

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

struct ConfettiView: View {
    @State private var particles: [(offset: CGSize, opacity: Double, color: Color)] = []
    var body: some View {
        GeometryReader { geometry in
            ForEach(0..<particles.count, id: \\.self) { i in
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

struct ExportView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @ObservedObject var exportVM: ExportViewModel

    private var theme: AppTheme { themeManager.currentTheme }
    @State private var showFileExporter = false
    @State private var exportFileName: String = "modelo"
    @State private var showProgress = false
    @State private var exportProgress: Double = 0
    @State private var exportSuccess = false
    @State private var rotationAngle: Double = 0
    @State private var showARPreview = false
    @State private var arUSDZURL: URL?

    var body: some View {
        ZStack {
            VStack(spacing: 24) {
                // Header with tap-to-rotate icon
                VStack(spacing: 8) {
                    Image(systemName: "square.and.arrow.up.fill")
                        .font(.system(size: 48)).foregroundColor(.accentColor)
                        .rotationEffect(.degrees(rotationAngle))
                        .onTapGesture { withAnimation(.spring(response: 0.4, dampingFraction: 0.5)) { rotationAngle += 360 } }
                    Text("Exportar Modelo").font(.title2.bold()).foregroundColor(theme.textPrimary)
                    Text("Exporta tu modelo 3D para impresion 3D o CAD").font(.caption).foregroundColor(theme.textSecondary)
                }.padding(.top, 32)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
                .animation(.easeOut(duration: 0.5).delay(0.0), value: exportVM.selectedModel != nil)

                // Model preview
                VStack(spacing: 8) {
                    if let model = exportVM.selectedModel {
                        ZStack {
                            RoundedRectangle(cornerRadius: 12).fill(theme.surfaceSecondary).frame(height: 180)
                            Image(systemName: "cube.transparent").font(.system(size: 64)).foregroundColor(.accentColor.opacity(0.3))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(model.name ?? "Modelo").font(.subheadline.bold()).foregroundColor(theme.textPrimary)
                                Text(String(format: "%d triangulos", model.triangleCount ?? 0)).font(.caption2).foregroundColor(theme.textSecondary)
                            }.padding(8).background(theme.surface).cornerRadius(8)
                        }
                    } else {
                        RoundedRectangle(cornerRadius: 12).fill(theme.surfaceSecondary).frame(height: 180)
                            .overlay(Image(systemName: "cube.transparent").font(.system(size: 40)).foregroundColor(theme.textSecondary.opacity(0.3)))
                    }
                }.padding(.horizontal)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
                .animation(.easeOut(duration: 0.5).delay(0.2), value: exportVM.selectedModel != nil)

                // Format selection + File name
                VStack(spacing: 16) {
                    HStack(spacing: 12) {
                        ForEach(["STL", "OBJ", "STEP", "USDZ", "GLTF"], id: \\.self) { fmt in
                            Button(action: { exportVM.selectedFormat = fmt }) {
                                Text(fmt).font(.caption.bold())
                                    .foregroundColor(exportVM.selectedFormat == fmt ? theme.textPrimary : theme.textSecondary)
                                    .padding(.horizontal, 12).padding(.vertical, 6)
                                    .background(exportVM.selectedFormat == fmt ? Color.accentColor : theme.surfaceSecondary)
                                    .cornerRadius(8)
                            }
                        }
                    }
                    TextField("Nombre del archivo", text: $exportFileName)
                        .textFieldStyle(.plain).font(.body).foregroundColor(theme.textPrimary)
                        .padding(12).background(theme.surfaceSecondary).cornerRadius(10)
                }.padding(.horizontal)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
                .animation(.easeOut(duration: 0.5).delay(0.4), value: exportVM.selectedModel != nil)

                // Progress bar
                if showProgress {
                    HStack(spacing: 16) {
                        CircularProgressView(progress: exportProgress)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Exportando...").font(.subheadline).foregroundColor(theme.textPrimary)
                            Text(String(format: "%.0f%% completado", exportProgress * 100)).font(.caption).foregroundColor(theme.textSecondary)
                        }
                    }.padding(.horizontal)
                    .transition(.scale.combined(with: .opacity))
                }

                // Export button
                Button(action: {
                    showProgress = true
                    exportProgress = 0
                    withAnimation(.spring(response: 1.5, dampingFraction: 0.8)) { exportProgress = 1.0 }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                        withAnimation(.easeOut(duration: 0.3)) {
                            exportSuccess = true
                            showFileExporter = true
                        }
                    }
                }) {
                    Label("Exportar", systemImage: "square.and.arrow.up")
                        .font(.headline).foregroundColor(theme.textPrimary)
                        .frame(maxWidth: .infinity).padding(.vertical, 14)
                        .background(Color.accentColor).cornerRadius(12)
                }.padding(.horizontal)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
                .animation(.easeOut(duration: 0.5).delay(0.6), value: exportVM.selectedModel != nil)

                // AR QuickLook button
                if exportVM.selectedFormat == .usdz {
                    Button(action: {
                        if let model = exportVM.selectedModel {
                            if let url = exportVM.prepareUSDZForAR(model: model, exportService: exportVM.exportService) {
                                arUSDZURL = url
                                showARPreview = true
                            }
                        }
                    }) {
                        Label("Ver en AR", systemImage: "arkit")
                            .font(.headline).foregroundColor(theme.textPrimary)
                            .frame(maxWidth: .infinity).padding(.vertical, 14)
                            .background(Color.green).cornerRadius(12)
                    }.padding(.horizontal)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }

            // Success overlay
            if exportSuccess {
                theme.surface.edgesIgnoringSafeArea(.all).transition(.opacity)
                ConfettiView().transition(.opacity)
                VStack(spacing: 16) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 64)).foregroundColor(.green)
                        .scaleEffect(exportSuccess ? 1 : 0)
                        .animation(.spring(response: 0.4, dampingFraction: 0.5), value: exportSuccess)
                    Text("Exportacion exitosa").font(.title2.bold()).foregroundColor(theme.textPrimary)
                    Text(String(format: "Modelo guardado como %@", exportFileName)).font(.caption).foregroundColor(theme.textSecondary)
                    Button("Cerrar") { withAnimation(.easeOut(duration: 0.3)) { exportSuccess = false; showProgress = false } }
                        .font(.headline).foregroundColor(.accentColor)
                        .padding(.horizontal, 32).padding(.vertical, 12)
                        .background(Color.accentColor.opacity(0.2)).cornerRadius(10)
                }.transition(.scale.combined(with: .opacity))
            }
        }.fileExporter(isPresented: $showFileExporter, document: exportVM.document, contentType: .data, defaultFilename: exportFileName) { result in
            if case .success = result { }
        }
        .sheet(isPresented: $showARPreview) {
            if let url = arUSDZURL {
                ARQuickLookView(usdzURL: url)
                    .edgesIgnoringSafeArea(.all)
            }
        }
    }
}