import SwiftUI

struct ConstraintOverlayView: View {
    @ObservedObject var constraintManager: GeometryConstraintManager
    var snapPoints: [SnapPoint] = []
    var activeSnapPoint: SnapPoint? = nil
    @State private var showOverlay: Bool = true

    private var iconMap: [ConstraintType: String] {
        [
            .horizontal: "\u{2192}",
            .vertical: "\u{2193}",
            .perpendicular: "\u{22A5}",
            .tangent: "\u{25CB}",
            .concentric: "\u{25CE}",
            .equal: "=",
            .distance: "\u{2194}",
            .angle: "\u{2220}",
            .midpoint: "M",
            .collinear: "\u{2014}"
        ]
    }

    private var activeConstraints: [GeometryConstraint] {
        constraintManager.getActiveConstraints()
    }

    private var overlayColor: Color {
        if activeConstraints.isEmpty { return Color.green }
        return constraintManager.lastSolve.converged ? Color.green : Color.red
    }

    var body: some View {
        VStack(spacing: 4) {
            Button(action: { showOverlay.toggle() }) {
                HStack {
                    Circle()
                        .fill(overlayColor)
                        .frame(width: 8, height: 8)
                    Text(showOverlay ? "Hide Constraints" : "Show Constraints")
                        .font(.caption)
                    Spacer()
                    Text("\(activeConstraints.count) active")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
            }

            if showOverlay {
                if !snapPoints.isEmpty {
                    SnapIndicatorView(
                        snapPoints: snapPoints,
                        activeSnapPoint: activeSnapPoint
                    )
                }

                if activeConstraints.isEmpty {
                    Text("No active constraints")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                } else {
                    ForEach(activeConstraints) { constraint in
                        HStack(spacing: 6) {
                            Text(iconMap[constraint.type] ?? "?")
                                .font(.system(size: 14))
                                .frame(width: 20, alignment: .center)
                            Text(constraint.label)
                                .font(.caption)
                            Spacer()
                            if let value = constraint.value {
                                Text(String(format: "%.2f", value))
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            Text("(\(constraint.entityIDs.count) entities)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 2)
                    }
                }

                HStack {
                    Text(
                        constraintManager.lastSolve.converged
                            ? "Solved: \(constraintManager.lastSolve.iterationCount) iter, residual: \(String(format: "%.2e", constraintManager.lastSolve.residual)), converged: true"
                            : "Solved: \(constraintManager.lastSolve.iterationCount) iter, residual: \(String(format: "%.2e", constraintManager.lastSolve.residual)), converged: false"
                    )
                    .font(.system(size: 8))
                    .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
            }
        }
    }
}

struct SnapIndicatorView: View {
    let snapPoints: [SnapPoint]
    var activeSnapPoint: SnapPoint?

    private let snapColor = Color(red: 0, green: 122/255.0, blue: 1)

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Snap Points (\(snapPoints.count))")
                .font(.system(size: 9))
                .foregroundColor(.secondary)
                .padding(.horizontal, 8)

            GeometryReader { geometry in
                ZStack {
                    ForEach(snapPoints) { point in
                        let isActive = point.id == activeSnapPoint?.id

                        Circle()
                            .fill(isActive ? snapColor : snapColor.opacity(0.4))
                            .frame(width: isActive ? 10 : 6, height: isActive ? 10 : 6)
                            .position(point.screenPosition)
                    }

                    if let active = activeSnapPoint {
                        ForEach(snapPoints.filter { $0.id != active.id }) { point in
                            Path { path in
                                path.move(to: active.screenPosition)
                                path.addLine(to: point.screenPosition)
                            }
                            .stroke(
                                snapColor.opacity(0.25),
                                style: StrokeStyle(
                                    lineWidth: 0.5,
                                    dash: [3, 3]
                                )
                            )
                        }
                    }
                }
            }
            .frame(height: 100)
            .background(Color.black.opacity(0.03))
            .cornerRadius(6)
            .padding(.horizontal, 8)
        }
    }
}
