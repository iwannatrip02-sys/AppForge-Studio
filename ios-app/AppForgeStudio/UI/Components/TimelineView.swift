import SwiftUI

struct TimelineView: View {
    @ObservedObject var engine: AnimationEngine
    @State private var dragTime: Float? = nil
    @State private var showAddKeyframe = false
    
    var body: some View {
        VStack(spacing: 8) {
            clipSelector
            transportControls
            timelineScrubber
            keyframeList
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
        .sheet(isPresented: $showAddKeyframe) {
            AddKeyframeSheet(engine: engine, isPresented: $showAddKeyframe)
        }
    }
    
    private var clipSelector: some View {
        HStack {
            Picker("Clip", selection: $engine.selectedClipName) {
                ForEach(Array(engine.clips.keys), id: \.self) { name in
                    Text(name).tag(name)
                }
            }
            .pickerStyle(.menu)
            Button(action: { showAddKeyframe = true }) {
                Image(systemName: "plus.circle.fill")
                    .foregroundColor(.accentColor)
            }
            .disabled(engine.selectedClipName.isEmpty)
        }
    }
    
    private var transportControls: some View {
        HStack(spacing: 20) {
            Button(action: { engine.stop() }) {
                Image(systemName: "stop.fill")
                    .foregroundColor(.red)
            }
            Button(action: { engine.togglePlayPause() }) {
                Image(systemName: engine.isPlaying ? "pause.fill" : "play.fill")
                    .foregroundColor(engine.selectedClipName.isEmpty ? .gray : .blue)
            }
            .disabled(engine.selectedClipName.isEmpty)
        }
        .font(.title2)
    }
    
    private var timelineScrubber: some View {
        VStack(spacing: 4) {
            Slider(value: Binding(
                get: { Double(dragTime ?? engine.currentTime) },
                set: { newValue in
                    let val = Float(newValue)
                    dragTime = val
                    engine.currentTime = val
                    engine.pause()
                }
            ), in: 0...(Double(engine.clips[engine.selectedClipName]?.duration ?? 1)))
            .disabled(engine.selectedClipName.isEmpty)
            
            HStack {
                Text(formatTime(engine.currentTime))
                    .font(.caption)
                    .foregroundColor(.white)
                Spacer()
                Text(formatTime(engine.clips[engine.selectedClipName]?.duration ?? 0))
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
    }
    
    private var keyframeList: some View {
        Group {
            if let clip = engine.clips[engine.selectedClipName], !engine.selectedClipName.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Keyframes")
                        .font(.caption.bold())
                        .foregroundColor(.white)
                    ForEach(engine.keyframes, id: \.id) { kf in
                        HStack {
                            Text(kf.type)
                                .font(.caption)
                                .foregroundColor(.accentColor)
                            Spacer()
                            Text(formatTime(kf.time))
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(6)
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                engine.removeKeyframe(id: kf.id)
                            } label: {
                                Label("Eliminar", systemImage: "trash")
                            }
                        }
                    }
                }
            }
        }
    }
}

struct AddKeyframeSheet: View {
    @ObservedObject var engine: AnimationEngine
    @Binding var isPresented: Bool
    @State private var selectedType = "posicion"
    @State private var keyframeTime: Float = 0
    @State private var modelName = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section("Tipo") {
                    Picker("Tipo", selection: $selectedType) {
                        ForEach(engine.keyframeTypes, id: \.self) { t in
                            Text(t).tag(t)
                        }
                    }
                }
                Section("Tiempo") {
                    Slider(value: Binding(
                        get: { Double(keyframeTime) },
                        set: { keyframeTime = Float($0) }
                    ), in: 0...(Double(engine.clips[engine.selectedClipName]?.duration ?? 1)))
                    Text("\(formatTime(keyframeTime))")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                Section("Modelo") {
                    TextField("Nombre del modelo", text: $modelName)
                }
            }
            .navigationTitle("Agregar Keyframe")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { isPresented = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Agregar") {
                        engine.addKeyframe(type: selectedType, time: keyframeTime, modelName: modelName)
                        isPresented = false
                    }
                }
            }
        }
    }
}

func formatTime(_ time: Float) -> String {
    let mins = Int(time) / 60
    let secs = Int(time) % 60
    let millis = Int((time - Float(Int(time))) * 100)
    return String(format: "%d:%02d.%02d", mins, secs, millis)
}
