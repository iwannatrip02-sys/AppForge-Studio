import SwiftUI

struct OnboardingView: View {
    @Binding var isOnboardingComplete: Bool
    @State private var currentPage = 0
    
    var body: some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)
            
            VStack {
                // Skip button
                HStack {
                    Spacer()
                    Button(action: {
                        UserDefaults.standard.set(true, forKey: "onboardingComplete")
                        withAnimation { isOnboardingComplete = true }
                    }) {
                        Text("Saltar")
                            .font(.caption)
                            .foregroundColor(.gray.opacity(0.7))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.gray.opacity(0.15))
                            .cornerRadius(8)
                    }
                    .padding(.trailing, 20)
                    .padding(.top, 16)
                }
                
                TabView(selection: $currentPage) {
                    // Page 1: Welcome
                    VStack(spacing: 24) {
                        Spacer()
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
                        Spacer()
                    }
                    .tag(0)
                    .transition(.scale.combined(with: .opacity))
                    
                    // Page 2: Modes
                    VStack(spacing: 24) {
                        Spacer()
                        Image(systemName: "square.3.layers.3d")
                            .font(.system(size: 72))
                            .foregroundColor(.accentColor)
                        Text("Modos de Trabajo")
                            .font(.title.bold())
                            .foregroundColor(.white)
                        VStack(alignment: .leading, spacing: 12) {
                            HStack { Image(systemName: "pencil.tip").frame(width: 28); Text("CAD: Modelado parametrico preciso").font(.body).foregroundColor(.gray) }
                            HStack { Image(systemName: "hand.draw").frame(width: 28); Text("Esculpir: Escultura digital intuitiva").font(.body).foregroundColor(.gray) }
                            HStack { Image(systemName: "paintpalette").frame(width: 28); Text("Pintar: Pintura 3D con pinceles").font(.body).foregroundColor(.gray) }
                            HStack { Image(systemName: "film").frame(width: 28); Text("Animacion: Keyframes y timeline").font(.body).foregroundColor(.gray) }
                        }
                        .padding(.horizontal, 40)
                        Spacer()
                    }
                    .tag(1)
                    .transition(.scale.combined(with: .opacity))
                    
                    // Page 3: Export
                    VStack(spacing: 24) {
                        Spacer()
                        Image(systemName: "square.and.arrow.up.fill")
                            .font(.system(size: 72))
                            .foregroundColor(.accentColor)
                        Text("Exporta a Impresion 3D")
                            .font(.title.bold())
                            .foregroundColor(.white)
                        Text("Exporta tus modelos a STL, OBJ, STEP o USDZ para imprimirlos o compartirlos")
                            .font(.body)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                        Button(action: {
                            UserDefaults.standard.set(true, forKey: "onboardingComplete")
                            withAnimation { isOnboardingComplete = true }
                        }) {
                            HStack {
                                Text("Comenzar")
                                    .font(.headline)
                                Image(systemName: "arrow.right")
                                    .font(.headline)
                            }
                            .padding(.horizontal, 40)
                            .padding(.vertical, 12)
                            .background(Color.accentColor)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                        Spacer()
                    }
                    .tag(2)
                    .transition(.scale.combined(with: .opacity))
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.spring(response: 0.5, dampingFraction: 0.8), value: currentPage)
                
                // Page indicators
                HStack(spacing: 8) {
                    ForEach(0..<3) { index in
                        Circle()
                            .fill(currentPage == index ? Color.accentColor : Color.gray.opacity(0.4))
                            .frame(width: currentPage == index ? 10 : 8, height: currentPage == index ? 10 : 8)
                            .animation(.spring(response: 0.3), value: currentPage)
                    }
                }
                .padding(.bottom, 40)
                
                // Navigation buttons
                HStack(spacing: 20) {
                    if currentPage > 0 {
                        Button(action: { withAnimation { currentPage -= 1 } }) {
                            Text("Atras")
                                .font(.headline)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 10)
                                .background(Color.gray.opacity(0.3))
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }
                    }
                    if currentPage < 2 {
                        Button(action: { withAnimation { currentPage += 1 } }) {
                            Text("Siguiente")
                                .font(.headline)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 10)
                                .background(Color.accentColor)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }
                    }
                }
                .padding(.bottom, 60)
            }
        }
    }
}