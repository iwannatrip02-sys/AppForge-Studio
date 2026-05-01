import SwiftUI

struct GridView2: View {
    let gridSize: Double
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        Canvas { context, size in
            let step = size.width / gridSize
            for i in 0...Int(gridSize) {
                let x = Double(i) * step
                let y = Double(i) * step
                context.stroke(Path { path in
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: size.height))
                }, with: .color(themeManager.currentTheme.border), lineWidth: 0.5)
                context.stroke(Path { path in
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: size.width, y: y))
                }, with: .color(themeManager.currentTheme.border), lineWidth: 0.5)
            }
        }
    }
}
