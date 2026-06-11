import SwiftUI
import OSLog

private let logger = Logger(subsystem: "com.appforgestudio", category: "TimelineView")
struct TimelineView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @ObservedObject var engine: AnimationEngine
    @State private var dragTime: Float? = nil

    private var theme: AppTheme { themeManager.currentTheme }
    @State private var showAddKeyframe = false
    @State private var draggedKeyframe: AnimationEngine.KeyframeEntry? = nil
    @State private var dragOffset: CGFloat = 0
    
    var body: some View {
        VStack(spacing: 8) {
            clipSelector
            transportControls
            timelineScrubber
            keyframeList
        }
        .padding()
        .background(theme.surfaceSecondary)
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
                    .foregroundColor(engine.selectedClipName.isEmpty ? theme.textSecondary : .blue)
            }
            .disabled(engine.selectedClipName.isEmpty)
        }
        .font(.title2)
    }
    
    private var timelineScrubber: some View {
        let duration = engine.clips[engine.selectedClipName]?.duration ?? 1.0
        return VStack(spacing: 4) {
            Slider(value: Binding(
                get: { Double(dragTime ?? engine.currentTime) },
                set: { newValue in
                    dragTime = Float(newValue)
                    engine.currentTime = Float(newValue)
                    engine.seek(to: Float(newValue))
                }
            ), in: 0...Double(duration), step: 0.016)
            .accentColor(.blue)
            
            HStack {
                Text(String(format: "%.1fs", dragTime ?? engine.currentTime))
                    .font(.caption2.monospacedDigit())
                    .foregroundColor(theme.textPrimary)
                Spacer()
                Text(String(format: "%.1fs", duration))
                    .font(.caption2.monospacedDigit())
                    .foregroundColor(theme.textSecondary)
            }
        }
        .padding(.horizontal, 4)
    }
    
    private var keyframeList: some View {
        let duration = engine.clips[engine.selectedClipName]?.duration ?? 1.0
        let filtered = engine.keyframes.filter { $0.modelName == engine.selectedClipName }
        return VStack(alignment: .leading, spacing: 6) {
            Text("Keyframes")
                .font(.caption.bold())
                .foregroundColor(theme.textSecondary)
            
            if filtered.isEmpty {
                Text("Sin keyframes. Anade uno con +")
                    .font(.caption2)
                    .foregroundColor(theme.textSecondary.opacity(0.6))
                    .padding(.vertical, 8)
            } else {
                ForEach(filtered) { kf in
                    keyframeRow(kf: kf, duration: duration)
                }
            }
        }
    }
    
    private func keyframeRow(kf: AnimationEngine.KeyframeEntry, duration: Float) -> some View {
        let pos = duration > 0 ? CGFloat(kf.time / duration) : 0
        let color: Color = {
            switch kf.type {
            case "posicion": return .green
            case "rotacion": return .blue
            case "escala": return .orange
            default: return .accentColor
            }
        }()
        
        return HStack(spacing: 8) {
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(theme.surfaceSecondary)
                    .frame(height: 28)
                
                Circle()
                    .fill(color)
                    .frame(width: 14, height: 14)
                    .offset(x: pos * (UIScreen.main.bounds.width - 120) - 7)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                draggedKeyframe = kf
                                let newOffset = value.translation.width
                                let totalWidth = UIScreen.main.bounds.width - 120
                                let newTime = max(0, min(Float(duration), Float(newOffset / totalWidth) * duration))
                                if let idx = engine.keyframes.firstIndex(where: { $0.id == kf.id }) {
                                    engine.keyframes[idx].time = newTime
                                }
                            }
                            .onEnded { value in
                                let totalWidth = UIScreen.main.bounds.width - 120
                                let rawTime = max(0, min(Float(duration), Float(value.translation.width / totalWidth) * duration))
                                let snappedTime = round(rawTime * 2) / 2.0
                                if let idx = engine.keyframes.firstIndex(where: { $0.id == kf.id }) {
                                    engine.keyframes[idx].time = min(snappedTime, Float(duration))
                                }
                                draggedKeyframe = nil
                            }
                    )
                    .contextMenu {
                        Button(action: { engine.removeKeyframe(at: kf.time) }) {
                            Label("Eliminar", systemImage: "trash")
                        }
                        Button(action: {
                            let newTime = min(kf.time + 0.5, Float(duration))
                            engine.addKeyframe(type: kf.type, time: newTime, modelName: kf.modelName)
                        }) {
                            Label("Duplicar", systemImage: "plus.square")
                        }
                    }
            }
            
            Text(String(format: "%.1fs", kf.time))
                .font(.caption2.monospacedDigit())
                .foregroundColor(color)
                .frame(width: 40)
        }
        .padding(.vertical, 2)
    }
}