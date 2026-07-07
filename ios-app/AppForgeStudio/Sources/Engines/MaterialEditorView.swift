import SwiftUI
import OSLog

private let logger = Logger(subsystem: "com.appforgestudio", category: "MaterialEditorView")
struct MaterialEditorView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @ObservedObject var materialVM: MaterialEditorViewModel
    @ObservedObject var canvasVM: CanvasViewModel
    var renderer: SatinRenderer

    @State private var selectedCategory: MaterialPresets.Preset.Category = .metal

    private var theme: AppTheme { themeManager.currentTheme }

    var body: some View {
        VStack(spacing: 0) {
            MetalView(
                scene: $canvasVM.scene,
                strokes: .constant([]),
                renderer: renderer,
                animationEngine: nil,
                metalBackground: themeManager.currentTheme.metalBackground
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            ScrollView(.vertical, showsIndicators: false) {
                materialPanel
            }
            .background(theme.surface)
            .frame(maxHeight: 320)
        }
        .background(theme.background)
        .sheet(isPresented: $materialVM.showPresetSheet) {
            PresetBrowserView(materialVM: materialVM, theme: theme)
        }
        .onAppear { materialVM.pullFromModel() }
        .onChange(of: canvasVM.selectedModelIndex) { _ in
            materialVM.pullFromModel()
        }
    }

    private var materialPanel: some View {
        VStack(spacing: 12) {
            if materialVM.selectedModel == nil {
                Text("Selecciona un modelo para editar su material")
                    .font(.caption)
                    .foregroundColor(theme.textSecondary)
                    .padding(.vertical, 20)
            } else {
                headerSection
                Divider().background(theme.border)
                pbrToggleSection
                if materialVM.usesPBR {
                    Divider().background(theme.border)
                    albedoSection
                    Divider().background(theme.border)
                    slidersSection
                    Divider().background(theme.border)
                    emissionSection
                    Divider().background(theme.border)
                    presetsSection
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Editor de Material")
                    .font(.headline)
                    .foregroundColor(theme.textPrimary)
                Text(materialVM.selectedModel?.name ?? "")
                    .font(.caption)
                    .foregroundColor(theme.textSecondary)
            }
            Spacer()
            Circle()
                .fill(materialVM.albedoColor)
                .frame(width: 32, height: 32)
                .overlay(Circle().stroke(theme.border, lineWidth: 1.5))
        }
    }

    private var pbrToggleSection: some View {
        HStack {
            Label("Material PBR", systemImage: "cube.fill")
                .font(.subheadline)
                .foregroundColor(theme.textPrimary)
            Spacer()
            Toggle("", isOn: $materialVM.usesPBR)
                .toggleStyle(SwitchToggleStyle(tint: .accentColor))
                .labelsHidden()
        }
    }

    private var albedoSection: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Albedo")
                    .font(.subheadline)
                    .foregroundColor(theme.textSecondary)
                Spacer()
            }
            ColorPicker("Color Base", selection: $materialVM.albedoColor, supportsOpacity: false)
                .labelsHidden()
                .scaleEffect(1.2)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var slidersSection: some View {
        VStack(spacing: 10) {
            sliderRow(
                label: "Metalico",
                systemImage: "bolt.fill",
                value: $materialVM.metallic,
                range: 0...1,
                format: "%.2f",
                color: .yellow
            )
            sliderRow(
                label: "Rugosidad",
                systemImage: "circle.dotted",
                value: $materialVM.roughness,
                range: 0...1,
                format: "%.2f",
                color: .gray
            )
            sliderRow(
                label: "AO",
                systemImage: "shadow",
                value: $materialVM.ao,
                range: 0...1,
                format: "%.2f",
                color: .indigo
            )
        }
    }

    private var emissionSection: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Emision")
                    .font(.subheadline)
                    .foregroundColor(theme.textSecondary)
                Spacer()
                if materialVM.emissionIntensity > 0 {
                    Circle()
                        .fill(materialVM.emissionColor)
                        .frame(width: 14, height: 14)
                        .shadow(color: materialVM.emissionColor, radius: 4)
                }
            }
            ColorPicker("Color Emision", selection: $materialVM.emissionColor, supportsOpacity: false)
                .labelsHidden()
                .scaleEffect(1.1)
                .frame(maxWidth: .infinity, alignment: .leading)
                .disabled(materialVM.emissionIntensity <= 0)
            sliderRow(
                label: "Intensidad",
                systemImage: "sun.max.fill",
                value: $materialVM.emissionIntensity,
                range: 0...5,
                format: "%.1f",
                color: .orange
            )
        }
    }

    private var presetsSection: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Presets")
                    .font(.subheadline)
                    .foregroundColor(theme.textSecondary)
                Spacer()
                Button(action: { materialVM.showPresetSheet = true }) {
                    Label("Biblioteca", systemImage: "books.vertical.fill")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(MaterialPresets.all.prefix(10)) { preset in
                        presetChip(preset)
                    }
                }
            }
        }
    }

    private func presetChip(_ preset: MaterialPresets.Preset) -> some View {
        Button(action: { materialVM.applyPreset(preset) }) {
            VStack(spacing: 4) {
                Circle()
                    .fill(Color(
                        red: Double(preset.material.albedo.x),
                        green: Double(preset.material.albedo.y),
                        blue: Double(preset.material.albedo.z)
                    ))
                    .frame(width: 28, height: 28)
                    .overlay(Circle().stroke(theme.border, lineWidth: 1))
                Text(preset.name)
                    .font(.system(size: 9))
                    .foregroundColor(theme.textSecondary)
                    .lineLimit(1)
            }
            .frame(width: 52)
        }
        .buttonStyle(.plain)
    }

    private func sliderRow(
        label: String,
        systemImage: String,
        value: Binding<Float>,
        range: ClosedRange<Float>,
        format: String,
        color: Color
    ) -> some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.caption2)
                .foregroundColor(color)
                .frame(width: 16)
            Text(label)
                .font(.caption)
                .foregroundColor(theme.textPrimary)
                .frame(width: 70, alignment: .leading)
            Slider(value: value, in: range)
                .tint(color)
            Text(String(format: format, value.wrappedValue))
                .font(.caption2)
                .foregroundColor(theme.textSecondary)
                .frame(width: 32, alignment: .trailing)
        }
    }
}

private struct PresetBrowserView: View {
    @ObservedObject var materialVM: MaterialEditorViewModel
    let theme: AppTheme
    @Environment(\.dismiss) var dismiss
    @State private var selectedCategory: MaterialPresets.Preset.Category = .metal

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Categoria", selection: $selectedCategory) {
                    ForEach(MaterialPresets.Preset.Category.allCases) { cat in
                        Text(cat.rawValue).tag(cat)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.vertical, 8)

                ScrollView {
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 12) {
                        ForEach(filteredPresets) { preset in
                            presetCard(preset)
                        }
                    }
                    .padding()
                }
            }
            .background(theme.background)
            .navigationTitle("Biblioteca de Materiales")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cerrar") { dismiss() }
                        .font(.caption)
                }
            }
        }
    }

    private var filteredPresets: [MaterialPresets.Preset] {
        MaterialPresets.all.filter { $0.category == selectedCategory }
    }

    private func presetCard(_ preset: MaterialPresets.Preset) -> some View {
        Button(action: {
            materialVM.applyPreset(preset)
            dismiss()
        }) {
            VStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(
                        red: Double(preset.material.albedo.x),
                        green: Double(preset.material.albedo.y),
                        blue: Double(preset.material.albedo.z)
                    ))
                    .frame(height: 50)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(theme.border, lineWidth: 1)
                    )
                    .overlay(
                        Group {
                            if preset.material.metalness > 0.5 {
                                VStack {
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(LinearGradient(
                                            gradient: Gradient(colors: [.white.opacity(0.4), .clear]),
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ))
                                }
                            }
                        }
                    )

                Text(preset.name)
                    .font(.caption2)
                    .foregroundColor(theme.textPrimary)
                    .lineLimit(1)

                HStack(spacing: 4) {
                    if preset.material.metalness > 0 {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 7))
                            .foregroundColor(.yellow)
                    }
                    if preset.material.roughness < 0.3 {
                        Image(systemName: "sparkles")
                            .font(.system(size: 7))
                            .foregroundColor(.blue)
                    }
                    if preset.material.emissionIntensity > 0 {
                        Image(systemName: "sun.max.fill")
                            .font(.system(size: 7))
                            .foregroundColor(.orange)
                    }
                }

                Text(preset.category.rawValue)
                    .font(.system(size: 8))
                    .foregroundColor(theme.textSecondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(theme.surfaceSecondary)
                    .cornerRadius(4)
            }
            .padding(8)
            .background(theme.surfaceSecondary)
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
}
