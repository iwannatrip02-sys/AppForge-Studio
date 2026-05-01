import SwiftUI

struct ContentView: View {
    @StateObject var canvasVM: CanvasViewModel
    let renderer: SatinRenderer
    @EnvironmentObject var themeManager: ThemeManager

    var body: some View {
        ZStack {
            SatinView(renderer: renderer, metalBackground: themeManager.currentTheme.metalBackground)
                .edgesIgnoringSafeArea(.all)
            
            VStack {
                Spacer()
                HStack {
                    Button(action: { canvasVM.undo() }) {
                        Image(systemName: "arrow.uturn.backward")
                    }
                    Button(action: { canvasVM.redo() }) {
                        Image(systemName: "arrow.uturn.forward")
                    }
                    Spacer()
                    Text("Mode: \(canvasVM.currentMode.rawValue)")
                        .font(.caption)
                        .padding(4)
                        .background(.ultraThinMaterial)
                        .cornerRadius(4)
                    Spacer()
                    Button(action: { canvasVM.resetView() }) {
                        Image(systemName: "arrow.counterclockwise")
                    }
                }
                .padding()
                .background(.ultraThinMaterial)
            }
        }
    }
}

struct SatinView: UIViewRepresentable {
    let renderer: SatinRenderer
    let metalBackground: UIColor

    func makeUIView(context: Context) -> MTKView {
        let view = MTKView()
        view.device = renderer.device
        view.delegate = renderer
        view.framebufferOnly = false
        view.enableSetNeedsDisplay = true
        view.backgroundColor = metalBackground
        return view
    }
    
    func updateUIView(_ uiView: MTKView, context: Context) {
        uiView.backgroundColor = metalBackground
    }
}
