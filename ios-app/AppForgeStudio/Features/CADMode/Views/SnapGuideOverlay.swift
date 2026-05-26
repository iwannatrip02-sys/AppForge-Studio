import SwiftUI
import simd
import CoreGraphics

struct SnapGuideOverlay: View {
    let snapPoints: [SnapPoint]
    let cursorScreenPosition: CGPoint
    let isActive: Bool

    @State private var pulsePhase: CGFloat = 0

    private let snapColor = Color(red: 0, green: 122/255.0, blue: 1)
    private let glowColor = Color(red: 0, green: 122/255.0, blue: 1, opacity: 0.3)
    private let dashPattern: [CGFloat] = [4, 4]

    private var nearestPoint: SnapPoint? {
        guard !snapPoints.isEmpty else { return nil }
        var best: SnapPoint? = nil
        var bestDist: CGFloat = .infinity
        for p in snapPoints {
            let dx = p.screenPosition.x - cursorScreenPosition.x
            let dy = p.screenPosition.y - cursorScreenPosition.y
            let dist = sqrt(dx * dx + dy * dy)
            if dist < bestDist {
                bestDist = dist
                best = p
            }
        }
        guard let best = best, bestDist < 50 else { return nil }
        return best
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                if isActive {
                    ForEach(snapPoints) { point in
                        let isNearest = point.id == nearestPoint?.id

                        Circle()
                            .fill(isNearest ? snapColor : snapColor.opacity(0.6))
                            .frame(
                                width: isNearest ? 12 * (1 + 0.15 * pulsePhase) : 8,
                                height: isNearest ? 12 * (1 + 0.15 * pulsePhase) : 8
                            )
                            .overlay(
                                Circle()
                                    .stroke(glowColor, lineWidth: isNearest ? 4 : 0)
                                    .blur(radius: 2)
                            )
                            .position(point.screenPosition)
                    }

                    if let nearest = nearestPoint {
                        Path { path in
                            path.move(to: cursorScreenPosition)
                            path.addLine(to: nearest.screenPosition)
                        }
                        .stroke(
                            style: StrokeStyle(
                                lineWidth: 1,
                                dash: dashPattern
                            )
                        )
                        .foregroundColor(snapColor.opacity(0.8))
                    }
                }
            }
            .opacity(isActive ? 1 : 0)
            .animation(.easeIn(duration: 0.15), value: isActive)
            .onAppear {
                if isActive {
                    withAnimation(
                        .easeInOut(duration: 0.8)
                        .repeatForever(autoreverses: true)
                    ) {
                        pulsePhase = 1
                    }
                }
            }
            .onChange(of: isActive) { active in
                if active {
                    withAnimation(
                        .easeInOut(duration: 0.8)
                        .repeatForever(autoreverses: true)
                    ) {
                        pulsePhase = 1
                    }
                } else {
                    pulsePhase = 0
                }
            }
            .drawingGroup()
            .allowsHitTesting(false)
        }
    }
}
