import SwiftUI
import OSLog

private let logger = Logger(subsystem: "com.appforgestudio", category: "CADTimelineView")

struct CADTimelineView: View {
    @ObservedObject var historyTree: CADHistoryTree
    @EnvironmentObject var themeManager: ThemeManager
    @State private var showClearConfirm = false

    private var theme: AppTheme { themeManager.currentTheme }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                toolbar
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        if historyTree.rootNodes.isEmpty {
                            emptyState
                        } else {
                            ForEach(historyTree.rootNodes) { node in
                                CADNodeRow(node: node, historyTree: historyTree, depth: 0)
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
            .navigationTitle("Historial CAD")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var toolbar: some View {
        HStack(spacing: 12) {
            Button(action: {
                historyTree.undo()
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }) {
                Image(systemName: "arrow.uturn.backward")
                    .font(.system(size: 14))
            }
            .disabled(!historyTree.canUndo)

            Button(action: {
                historyTree.redo()
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }) {
                Image(systemName: "arrow.uturn.forward")
                    .font(.system(size: 14))
            }
            .disabled(!historyTree.canRedo)

            Spacer()

            Text("\(historyTree.operationCount) ops")
                .font(.caption2)
                .foregroundColor(theme.textSecondary)

            Button(action: { showClearConfirm = true }) {
                Image(systemName: "trash")
                    .font(.system(size: 13))
                    .foregroundColor(theme.error)
            }
            .accessibilityLabel("Borrar todo el historial")
            // Borrar TODO el historial es destructivo: confirmación obligatoria
            // (feedback de device: 'le di borrar y se borró todo' sin aviso).
            .confirmationDialog("¿Borrar todo el historial?",
                                isPresented: $showClearConfirm, titleVisibility: .visible) {
                Button("Borrar \(historyTree.operationCount) operaciones", role: .destructive) {
                    historyTree.clear()
                    HapticService.shared.heavy()
                }
                Button("Cancelar", role: .cancel) {}
            } message: {
                Text("Esta acción no se puede deshacer.")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(theme.surfaceSecondary)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "clock.badge.questionmark")
                .font(.system(size: 32))
                .foregroundColor(theme.textSecondary.opacity(0.4))
            Text("No hay operaciones en el historial")
                .font(.caption)
                .foregroundColor(theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}

struct CADNodeRow: View {
    let node: CADFeatureNode
    @ObservedObject var historyTree: CADHistoryTree
    let depth: Int
    @EnvironmentObject var themeManager: ThemeManager
    @State private var isExpanded = true

    private var theme: AppTheme { themeManager.currentTheme }
    private var isCurrent: Bool { node.id == historyTree.currentNode?.id }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                if !node.children.isEmpty {
                    Button(action: {
                        isExpanded.toggle()
                    }) {
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .font(.system(size: 9))
                            .foregroundColor(theme.textSecondary)
                    }
                } else {
                    Rectangle()
                        .fill(Color.clear)
                        .frame(width: 10, height: 10)
                }

                Image(systemName: node.operation.type.icon)
                    .font(.system(size: 13))
                    .foregroundColor(colorFor(node.operation.type))
                    .frame(width: 18)

                // Tamaños legibles en iPad (feedback de device: "muy pequeño")
                VStack(alignment: .leading, spacing: 1) {
                    Text(node.operation.description)
                        .font(.system(size: 13))
                        .foregroundColor(isCurrent ? theme.textPrimary : theme.textSecondary)
                        .lineLimit(1)

                    Text(relativeTimestamp(from: node.operation.timestamp))
                        .font(.system(size: 10))
                        .foregroundColor(theme.textSecondary.opacity(0.6))
                }

                Spacer()

                if isCurrent {
                    Circle()
                        .fill(AppTheme.accentColor)
                        .frame(width: 6, height: 6)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .padding(.leading, CGFloat(depth) * 20)
            .background(isCurrent ? AppTheme.accentColor.opacity(0.08) : Color.clear)
            .contentShape(Rectangle())
            .onTapGesture {
                historyTree.selectedNodeID = node.id
                historyTree.objectWillChange.send()
            }
            .transition(.slide)

            if isExpanded {
                ForEach(node.children) { child in
                    CADNodeRow(node: child, historyTree: historyTree, depth: depth + 1)
                }
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isExpanded)
    }

    private func colorFor(_ type: CADOperationType) -> Color {
        switch type {
        case .createPrimitive: return .blue
        case .extrude, .sketchExtrude, .pushPull: return .orange
        case .revolve, .sketchRevolve: return .purple
        case .sweep, .sketchSweep: return .indigo
        case .loft, .sketchLoft: return .teal
        case .booleanUnion, .booleanSubtract, .booleanIntersect: return .cyan
        case .fillet, .chamfer: return .green
        case .shell, .hole: return .mint
        case .move, .rotate, .scale, .mirror, .pattern: return .gray
        case .delete: return .red
        }
    }

    private func relativeTimestamp(from date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        if interval < 60 { return "ahora" }
        if interval < 3600 { return "hace \(Int(interval / 60))m" }
        if interval < 86400 { return "hace \(Int(interval / 3600))h" }
        return "hace \(Int(interval / 86400))d"
    }
}
