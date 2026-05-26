import SwiftUI
import Satin
import OSLog

private let logger = Logger(subsystem: "com.appforgestudio", category: "LayerPanelView")
/// Panel lateral de capas arrastrables con visibilidad, bloqueo y selección
struct LayerPanelView: View {
    @ObservedObject var sceneManager: SceneManager
    @Binding var isPresented: Bool
    
    var body: some View {
        NavigationView {
            List {
                ForEach(sceneManager.layers) { layer in
                    LayerRow(layer: layer, sceneManager: sceneManager)
                }
                .onMove { indices, newOffset in
                    sceneManager.layers.move(fromOffsets: indices, toOffset: newOffset)
                }
            }
            .listStyle(.inset)
            .navigationTitle("Layers")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack {
                        Button(action: { sceneManager.addLayer() }) {
                            Image(systemName: "plus")
                        }
                        EditButton()
                    }
                }
            }
        }
    }
}

struct LayerRow: View {
    let layer: SceneLayer
    let sceneManager: SceneManager
    
    var body: some View {
        HStack {
            Button(action: { sceneManager.toggleLayerVisibility(layer.id) }) {
                Image(systemName: layer.isVisible ? "eye.fill" : "eye.slash")
                    .foregroundColor(layer.isVisible ? .blue : .gray)
            }
            .buttonStyle(.plain)
            
            VStack(alignment: .leading) {
                Text(layer.name)
                    .font(.body)
                Text("\(layer.meshes.count) objects")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if sceneManager.activeLayerId == layer.id {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.accentColor)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            sceneManager.activeLayerId = layer.id
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                sceneManager.removeLayer(id: layer.id)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}
