import SwiftUI

struct ColorPickerView: View {
    @Binding var selectedColor: Color
    @Binding var brushSize: Float
    @Binding var brushStrength: Float
    
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
                .foregroundColor(.white)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 6) {
                ForEach(palette, id: \.0) { _, color in
                    Circle()
                        .fill(color)
                        .frame(width: 26, height: 26)
                        .overlay(
                            Circle()
                                .stroke(selectedColor == color ? Color.white : Color.clear, lineWidth: 2)
                        )
                        .onTapGesture { selectedColor = color }
                }
            }
            
            HStack {
                Text("Tam: \(String(format: "%.2f", brushSize))")
                    .font(.caption2)
                    .foregroundColor(.white)
                Slider(value: $brushSize, in: 0.01...0.5)
                    .tint(.accentColor)
            }
            HStack {
                Text("Fza: \(String(format: "%.1f", brushStrength))")
                    .font(.caption2)
                    .foregroundColor(.white)
                Slider(value: $brushStrength, in: 0.1...1.0)
                    .tint(.accentColor)
            }
        }
        .padding()
        .background(Color(.systemGray6).opacity(0.15))
        .cornerRadius(12)
    }
}