import SwiftUI
import MetalKit

struct LoadingScreenView: View {
    @Binding var progress: Double
    @Binding var isLoading: Bool
    @State private var rotateDegrees: Double = 0
    
    var body: some View {
        ZStack {
            MetalLoadingBackground()
                .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 20) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.5)
                
                Text('Cargando modelo 3D...')
                    .font(.headline)
                    .foregroundColor(.white.opacity(0.8))
                
                ProgressView(value: min(progress, 1.0))
                    .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                    .frame(width: 200)
                
                Text(String(format: '%.0f%%', min(progress * 100, 100)))
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            .opacity(isLoading ? 1 : 0)
            .animation(.easeInOut(duration: 0.3), value: isLoading)
        }
    }
}

struct MetalLoadingBackground: UIViewRepresentable {
    func makeUIView(context: Context) -> MTKView {
        let mtkView = MTKView()
        mtkView.device = MTLCreateSystemDefaultDevice()
        mtkView.backgroundColor = UIColor(red: 0.08, green: 0.08, blue: 0.12, alpha: 1.0)
        mtkView.isPaused = true
        mtkView.enableSetNeedsDisplay = false
        return mtkView
    }
    
    func updateUIView(_ uiView: MTKView, context: Context) {}
}
