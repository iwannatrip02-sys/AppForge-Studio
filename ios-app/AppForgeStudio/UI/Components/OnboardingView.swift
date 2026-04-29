import SwiftUI

struct OnboardingView: View {
    @Binding var isOnboardingComplete: Bool
    @State private var currentPage = 0
    
    var body: some View {
        VStack {
            TabView(selection: $currentPage) {
                // Page 1
                VStack(spacing: 24) {
                    Image(systemName: "cube.transparent")
                        .font(.system(size: 72))
                        .foregroundColor(.accentColor)
                    Text("Bienvenido a AppForge Studio")
                        .font(.title.bold())
                        .foregroundColor(.white)
                    Text("Crea modelos 3D, esculpe, pinta y anima")
                        .font(.body)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                    Button(action: { withAnimation { currentPage = 1 } }) {
                        Text("Siguiente")
                            .font(.headline)
                            .padding(.horizontal, 40).padding(.vertical, 12)
                            .background(Color.accentColor)
                            .foregroundColor(.white).cornerRadius(10)
                    }
                }
                .tag(0)
                
                // Page 2
                VStack(spacing: 24) {
                    Image(systemName: "square.3.layers.3d")
                        .font(.system(size: 72))
                        .foregroundColor(.accentColor)
                    Text("Modos de Trabajo")
                        .font(.title.bold())
                        .foregroundColor(.white)
                    VStack(alignment: .leading, spacing: 12) {
                        HStack { Image(systemName: "pencil.tip").frame(width: 28); Text("CAD: Modelado parametrico preciso") }.font(.body).foregroundColor(.gray)
                        HStack { Image(systemName: "hand.draw").frame(width: 28); Text("Escultura: Arcilla digital con pinceles") }.font(.body).foregroundColor(.gray)
                        HStack { Image(systemName: "paintpalette").frame(width: 28); Text("Pintura: Texturizado 3D en tiempo real") }.font(.body).foregroundColor(.gray)
                        HStack { Image(systemName: "play.rectangle").frame(width: 28); Text("Animacion: Keyframes y linea de tiempo") }.font(.body).foregroundColor(.gray)
                    }.padding(.horizontal, 40)
                    HStack(spacing: 20) {
                        Button(action: { withAnimation { currentPage = 0 } }) {
                            Text("Atras").font(.headline).foregroundColor(.gray)
                        }
                        Button(action: { withAnimation { currentPage = 2 } }) {
                            Text("Siguiente")
                                .font(.headline)
                                .padding(.horizontal, 40).padding(.vertical, 12)
                                .background(Color.accentColor)
                                .foregroundColor(.white).cornerRadius(10)
                        }
                    }
                }
                .tag(1)
                
                // Page 3
                VStack(spacing: 24) {
                    Image(systemName: "square.and.arrow.up.fill")
                        .font(.system(size: 72))
                        .foregroundColor(.accentColor)
                    Text("Exporta a Impresion 3D")
                        .font(.title.bold())
                        .foregroundColor(.white)
                    Text("Exporta tus modelos a STL/OBJ para impresion 3D o CAD profesional")
                        .font(.body)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                    Button(action: {
                        UserDefaults.standard.set(true, forKey: "onboardingComplete")
                        withAnimation { isOnboardingComplete = true }
                    }) {
                        Text("Comenzar")
                            .font(.headline)
                            .padding(.horizontal, 40).padding(.vertical, 12)
                            .background(Color.accentColor)
                            .foregroundColor(.white).cornerRadius(10)
                    }
                }
                .tag(2)
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .always))
            .indexViewStyle(PageIndexViewStyle(backgroundDisplayMode: .always))
        }
        .background(Color.black.edgesIgnoringSafeArea(.all))
    }
}
