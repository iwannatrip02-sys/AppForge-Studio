import SwiftUI
import simd

struct MeasureTool: View {
    @ObservedObject var toolVM: ToolViewModel
    @ObservedObject var canvasVM: CanvasViewModel

    @State private var pointA: SIMD3<Float>? = nil
    @State private var pointB: SIMD3<Float>? = nil
    @State private var isSettingPointA: Bool = true
    @State private var measuredDistance: Float = 0
    @State private var showResult: Bool = false

    private let lineColor = Color(red: 1, green: 149/255.0, blue: 0)
    private let markerSize: CGFloat = 8

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(isSettingPointA ? "Tap Point A" : "Tap Point B")
                    .font(.caption)
                    .foregroundColor(.primary)
                Spacer()
                Button("Reset") {
                    pointA = nil
                    pointB = nil
                    isSettingPointA = true
                    measuredDistance = 0
                    showResult = false
                }
                .font(.caption2)
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 3)

            if showResult {
                HStack {
                    Text("Distance:")
                        .font(.caption)
                        .foregroundColor(.primary)
                    Text(String(format: "%.2f mm", measuredDistance * 1000))
                        .font(.caption)
                        .foregroundColor(lineColor)
                        .fontWeight(.bold)
                    Text(String(format: "(%.3f in)", measuredDistance * 39.37))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 2)
                .background(Color.orange.opacity(0.08))
            }

            GeometryReader { geometry in
                ZStack {
                    if let pA = screenPosition(from: pointA, in: geometry) {
                        Circle()
                            .fill(lineColor)
                            .frame(width: markerSize, height: markerSize)
                            .position(pA)
                            .overlay(
                                Circle()
                                    .stroke(lineColor.opacity(0.4), lineWidth: 2)
                                    .frame(width: 16, height: 16)
                                    .position(pA)
                            )
                    }

                    if let pB = screenPosition(from: pointB, in: geometry),
                       let pA = screenPosition(from: pointA, in: geometry) {
                        Path { path in
                            path.move(to: pA)
                            path.addLine(to: pB)
                        }
                        .stroke(lineColor, style: StrokeStyle(lineWidth: 1.5, dash: [3, 3]))

                        let midX = (pA.x + pB.x) / 2
                        let midY = (pA.y + pB.y) / 2
                        Text(String(format: "%.2f mm", measuredDistance * 1000))
                            .font(.system(size: 10))
                            .foregroundColor(lineColor)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(Color.black.opacity(0.6))
                            .cornerRadius(4)
                            .position(x: midX, y: midY - 12)
                    }

                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture { location in
                            handleTap(at: location, in: geometry)
                        }
                }
            }
            .frame(height: 80)
            .background(Color.black.opacity(0.05))
        }
    }

    private func handleTap(at location: CGPoint, in geometry: GeometryProxy) {
        let hitPos = hitTest(at: location, in: geometry)
        if isSettingPointA {
            pointA = hitPos
            isSettingPointA = false
            pointB = nil
            showResult = false
        } else {
            pointB = hitPos
            isSettingPointA = true
            if let a = pointA, let b = pointB {
                // TODO(F3): re-wire MeasureEngine → CADShapeMeasureEngine (API uses CADShape, not SIMD3)
                measuredDistance = simd_distance(a, b)
                toolVM.measurementDistance = measuredDistance
                showResult = true
            }
        }
    }

    private func hitTest(at location: CGPoint, in geometry: GeometryProxy) -> SIMD3<Float> {
        let hitEngine = HitTestEngine()
        if let hit = hitEngine.hitTest(
            at: location,
            in: geometry.size,
            scene: canvasVM.scene
        ) {
            return hit.position
        }
        let midX = Float(location.x / geometry.size.width - 0.5) * 4
        let midY = Float((1 - location.y / geometry.size.height) - 0.5) * 3
        return SIMD3<Float>(midX, midY, 0)
    }

    private func screenPosition(
        from worldPos: SIMD3<Float>?,
        in geometry: GeometryProxy
    ) -> CGPoint? {
        guard let pos = worldPos else { return nil }
        let sx = CGFloat(pos.x / 4.0 + 0.5) * geometry.size.width
        let sy = CGFloat(1 - (pos.y / 3.0 + 0.5)) * geometry.size.height
        return CGPoint(x: sx, y: sy)
    }
}
