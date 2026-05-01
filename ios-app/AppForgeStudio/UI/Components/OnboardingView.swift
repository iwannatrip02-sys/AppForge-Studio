import SwiftUI

private let animationDuration: Double = 0.5
private let onboardingCurve = Animation.timingCurve(0.22, 1, 0.36, 1, duration: animationDuration)

struct OnboardingView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @Binding var isOnboardingComplete: Bool

    private var theme: AppTheme { themeManager.currentTheme }
    @State private var currentPage = 0
    @State private var showTutorial = false
    @State private var tutorialStep = 0
    @State private var animateStart = false
    @Namespace private var page0NS
    @Namespace private var page1NS
    @Namespace private var page2NS
    @Namespace private var page3NS
    @Namespace private var page4NS

    private let totalPages = 5

    private func namespace(for page: Int) -> Namespace.ID {
        switch page {
        case 0: return page0NS
        case 1: return page1NS
        case 2: return page2NS
        case 3: return page3NS
        case 4: return page4NS
        default: return page0NS
        }
    }

    var body: some View {
        ZStack {
            theme.background.edgesIgnoringSafeArea(.all)

            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    Button(action: {
                        UserDefaults.standard.set(true, forKey: "onboardingComplete")
                        withAnimation(.easeInOut(duration: 0.3)) { isOnboardingComplete = true }
                    }) {
                        Text("Saltar")
                            .font(.caption)
                            .foregroundColor(theme.textSecondary.opacity(0.7))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(theme.surfaceSecondary)
                            .cornerRadius(8)
                    }
                    .padding(.trailing, 20)
                    .padding(.top, 16)
                }

                GeometryReader { geometry in
                    ZStack {
                        ForEach(0..<totalPages, id: \.self) { index in
                            pageContent(for: index)
                                .frame(width: geometry.size.width)
                                .offset(x: CGFloat(index - currentPage) * geometry.size.width * 0.85)
                                .opacity(index == currentPage ? 1 : 0.4)
                                .scaleEffect(index == currentPage ? 1 : 0.88)
                                .blur(radius: index == currentPage ? 0 : 4)
                                .matchedGeometryEffect(id: "page-\(index)", in: namespace(for: index))
                        }
                    }
                    .animation(.easeInOut(duration: animationDuration), value: currentPage)
                }

                HStack(spacing: 8) {
                    ForEach(0..<totalPages, id: \.self) { index in
                        Circle()
                            .fill(index == currentPage ? theme.textPrimary : theme.textSecondary.opacity(0.4))
                            .frame(width: index == currentPage ? 10 : 8, height: index == currentPage ? 10 : 8)
                            .matchedGeometryEffect(id: "indicator-\(index)", in: namespace(for: index))
                            .onTapGesture {
                                withAnimation(.easeInOut(duration: animationDuration)) {
                                    currentPage = index
                                }
                            }
                    }
                }
                .padding(.vertical, 20)

                Button(action: {
                    if currentPage < totalPages - 1 {
                        withAnimation(onboardingCurve) {
                            currentPage += 1
                        }
                    } else {
                        UserDefaults.standard.set(true, forKey: "onboardingComplete")
                        withAnimation(.easeInOut(duration: 0.5)) {
                            isOnboardingComplete = true
                        }
                    }
                }) {
                    Text(currentPage < totalPages - 1 ? "Continuar" : "Comenzar")
                        .font(.headline)
                        .foregroundColor(theme.textPrimary)
                        .padding(.horizontal, 40)
                        .padding(.vertical, 14)
                        .background(Color.blue)
                        .cornerRadius(16)
                }
                .padding(.bottom, 40)
            }
        }
    }

    @ViewBuilder
    private func pageContent(for page: Int) -> some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: pageIcon(for: page))
                .font(.system(size: 80))
                .foregroundColor(.blue)
                .matchedGeometryEffect(id: "icon-\(page)", in: namespace(for: page))

            Text(pageTitle(for: page))
                .font(.title2.bold())
                .foregroundColor(theme.textPrimary)
                .matchedGeometryEffect(id: "title-\(page)", in: namespace(for: page))

            Text(pageDescription(for: page))
                .font(.body)
                .foregroundColor(theme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
                .matchedGeometryEffect(id: "desc-\(page)", in: namespace(for: page))

            Spacer()
        }
    }

    private func pageIcon(for page: Int) -> String {
        switch page {
        case 0: return "cube.transparent"
        case 1: return "hand.draw"
        case 2: return "paintpalette"
        case 3: return "film.stack"
        case 4: return "square.and.arrow.down"
        default: return "star"
        }
    }

    private func pageTitle(for page: Int) -> String {
        switch page {
        case 0: return "Modelado 3D"
        case 1: return "Escultura Digital"
        case 2: return "Pintura"
        case 3: return "Animacion"
        case 4: return "Exportacion"
        default: return ""
        }
    }

    private func pageDescription(for page: Int) -> String {
        switch page {
        case 0: return "Crea modelos 3D complejos con herramientas CAD profesionales directamente en tu iPad."
        case 1: return "Esculpe detalles finos con pinceles digitales, subdivision y herramientas de arcilla."
        case 2: return "Pinta directamente sobre tus modelos 3D con capas, texturas y efectos."
        case 3: return "Anima tus creaciones con keyframes, curvas de easing y timeline interactivo."
        case 4: return "Exporta a STL, OBJ, STEP y mas para impresion 3D o sharing."
        default: return ""
        }
    }
}