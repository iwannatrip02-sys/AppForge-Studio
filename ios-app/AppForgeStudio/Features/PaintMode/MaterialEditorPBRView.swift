import SwiftUI
import OSLog

private let logger = Logger(subsystem: "com.appforgestudio", category: "MaterialEditorPBRView")
struct MaterialEditorPBRView: View {
    @Binding var material: MaterialData
    var onApply: (MaterialData) -> Void
    @EnvironmentObject var themeManager: ThemeManager
    @State private var albedoColor: Color = Color(red: 0.8, green: 0.8, blue: 0.8)
    @State private var emissionColor: Color = Color(red: 0, green: 0, blue: 0)
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Preview
                previewSection
                Divider()
                // Name
                nameSection
                Divider()
                // Base Color
                colorSection
                Divider()
                // PBR Properties
                pbrSlidersSection
                Divider()
                // Actions
                actionButtons
            }
            .padding()
        }
        .background(themeManager.currentTheme.surface)
        .onAppear {
            albedoColor = Color(red: Double(material.albedo.x),
                                green: Double(material.albedo.y),
                                blue: Double(material.albedo.z))
            emissionColor = Color(red: Double(material.emission.x),
                                  green: Double(material.emission.y),
                                  blue: Double(material.emission.z))
        }
    }
    
    private var previewSection: some View {
        VStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 12)
                .fill(albedoColor)
                .frame(width: 80, height: 80)
                .overlay(
                    Circle()
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )
                .shadow(color: albedoColor.opacity(0.4), radius: 10)
            Text("Metallic: \(Int(material.metallic * 100))% | Roughness: \(Int(material.roughness * 100))%")
                .font(.caption2)
                .foregroundColor(themeManager.currentTheme.textSecondary)
        }
    }
    
    private var nameSection: some View {
        HStack {
            Text("Name")
                .foregroundColor(themeManager.currentTheme.textSecondary)
            TextField("Material name", text: $material.name)
                .textFieldStyle(.roundedBorder)
        }
    }
    
    private var colorSection: some View {
        VStack(spacing: 12) {
            ColorPicker("Albedo (Base Color)", selection: $albedoColor)
                .foregroundColor(themeManager.currentTheme.textPrimary)
                .onChange(of: albedoColor) { newColor in
                    if let components = newColor.cgColor?.components {
                        material.albedo = SIMD3<Float>(Float(components[0]), Float(components[1]), Float(components[2]))
                    }
                }
            ColorPicker("Emission (Glow)", selection: $emissionColor)
                .foregroundColor(themeManager.currentTheme.textPrimary)
                .onChange(of: emissionColor) { newColor in
                    if let components = newColor.cgColor?.components {
                        material.emission = SIMD3<Float>(Float(components[0]), Float(components[1]), Float(components[2]))
                    }
                }
        }
    }
    
    private var pbrSlidersSection: some View {
        VStack(spacing: 12) {
            sliderRow(label: "Metallic", value: $material.metallic, range: 0...1)
            sliderRow(label: "Roughness", value: $material.roughness, range: 0...1)
            sliderRow(label: "Normal Strength", value: $material.normalStrength, range: 0...2)
            sliderRow(label: "Occlusion", value: $material.occlusion, range: 0...1)
        }
    }
    
    private func sliderRow(label: String, value: Binding<Float>, range: ClosedRange<Float>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(.caption)
                    .foregroundColor(themeManager.currentTheme.textSecondary)
                Spacer()
                Text(String(format: "%.2f", value.wrappedValue))
                    .font(.caption.monospaced())
                    .foregroundColor(themeManager.currentTheme.textPrimary)
            }
            Slider(value: value, in: range)
                .tint(themeManager.currentTheme.accent)
        }
    }
    
    private var actionButtons: some View {
        HStack(spacing: 16) {
            Button("Cancel") {
                onApply(material)
            }
            .buttonStyle(.bordered)
            
            Button("Apply Material") {
                onApply(material)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(.top, 8)
    }
}
