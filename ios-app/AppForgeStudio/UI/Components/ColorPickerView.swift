import SwiftUI

struct ColorPickerView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @Binding var selectedColor: Color
    @Binding var brushSize: Float
    @Binding var brushStrength: Float

    private var theme: AppTheme { themeManager.currentTheme }

    let palette: [(String, Color)] = [
        ("Rojo", .red), ("Naranja", .orange), ("Amarillo", .yellow),
        ("Verde", .green), ("Azul", .blue), ("Indigo", .indigo),
        ("Violeta", .purple), ("Rosa", .pink), ("Marron", .brown),
        ("Gris", .gray), ("Negro", .black), ("Blanco", .white)
    ]
    
    var body: some View {
        VStack(spacing: 10) {
            Text("Selector de Color")
                .font(.caption)
                .foregroundColor(theme.textPrimary)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 6) {
                ForEach(palette, id: \.0) { _, color in
                    Circle()
                        .fill(color)
                        .frame(width: 26, height: 26)
                        .overlay(
                            Circle()
                                .stroke(selectedColor == color ? theme.textPrimary : Color.clear, lineWidth: 2)
                        )
                        .onTapGesture { selectedColor = color }
                }
            }
            
            HStack {
                Text("Tam: \(String(format: "%.2f", brushSize))")
                    .font(.caption2)
                    .foregroundColor(theme.textPrimary)
                Slider(value: $brushSize, in: 0.01...0.5)
                    .tint(.accentColor)
            }
            HStack {
                Text("Fza: \(String(format: "%.1f", brushStrength))")
                    .font(.caption2)
                    .foregroundColor(theme.textPrimary)
                Slider(value: $brushStrength, in: 0.1...1.0)
                    .tint(.accentColor)
            }
        }
        .padding()
        .background(theme.surfaceSecondary)
        .cornerRadius(12)
    }
}