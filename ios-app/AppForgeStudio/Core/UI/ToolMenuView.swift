import SwiftUI
import OSLog

private let logger = Logger(subsystem: "com.appforgestudio", category: "ToolMenuView")
/// Menú de herramientas flotante con selección de modo: Seleccionar, Pintar, Esculpir, Extruir
struct ToolMenuView: View {
    @Binding var selectedTool: ToolMode
    @State private var isExpanded = false
    
    var body: some View {
        VStack(spacing: 0) {
            if isExpanded {
                ForEach(ToolMode.allCases) { tool in
                    ToolMenuButton(tool: tool, isSelected: selectedTool == tool) {
                        selectedTool = tool
                        isExpanded = false
                    }
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            
            // Botón principal / toggle
            Button(action: { withAnimation { isExpanded.toggle() } }) {
                Image(systemName: selectedTool.icon)
                    .font(.title2)
                    .frame(width: 44, height: 44)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
            }
        }
        .padding(8)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22))
        .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
    }
}

struct ToolMenuButton: View {
    let tool: ToolMode
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Image(systemName: tool.icon)
                    .font(.title3)
                Text(tool.label)
                    .font(.caption2)
            }
            .frame(width: 52, height: 52)
            .background(isSelected ? Color.accentColor.opacity(0.2) : Color.clear)
            .foregroundColor(isSelected ? .accentColor : .primary)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }
}

enum ToolMode: String, CaseIterable, Identifiable {
    case select, paint, sculpt, extrude, rotate, scale
    
    var id: String { rawValue }
    
    var label: String {
        switch self {
        case .select:  return "Select"
        case .paint:   return "Paint"
        case .sculpt:  return "Sculpt"
        case .extrude: return "Extrude"
        case .rotate:  return "Rotate"
        case .scale:   return "Scale"
        }
    }
    
    var icon: String {
        switch self {
        case .select:  return "cursorarrow"
        case .paint:   return "paintbrush"
        case .sculpt:  return "hand.raised.fingers"
        case .extrude: return "square.3d.layers.mirror"
        case .rotate:  return "arrow.triangle.2.circlepath"
        case .scale:   return "arrow.up.left.and.down.right.magnifyingglass"
        }
    }
}
