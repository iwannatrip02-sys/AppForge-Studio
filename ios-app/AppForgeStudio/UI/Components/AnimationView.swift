import SwiftUI

struct AnimationView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @ObservedObject var engine: AnimationEngine
    @State private var draggingKeyframeId: UUID? = nil

    private var theme: AppTheme { themeManager.currentTheme }
    @State private var showEasingPicker = false
    @State private var selectedKfId: UUID? = nil
    
    private var currentClipDuration: Float {
        engine.clips[engine.selectedClipName]?.duration ?? 5.0
    }
    
    var body: some View {
        VStack(spacing: 12) {
            // Controls
            HStack(spacing: 16) {
                Button(action: { withAnimation(.spring(response: 0.3)) { engine.isPlaying.toggle() } }) {
                    Image(systemName: engine.isPlaying ? "pause.fill" : "play.fill")
                        .font(.title2)
                        .foregroundColor(theme.textPrimary)
                }
                .keyboardShortcut(" ", modifiers: [.command])
                .help(engine.isPlaying ? "Pausar animacion" : "Reproducir animacion")
                
                Slider(value: Binding(get: { Double(engine.currentTime) }, set: { engine.currentTime = Float($0) }), in: 0...Double(currentClipDuration), step: 0.016) {
                    Text("Tiempo")
                }
                .accentColor(.blue)
                
                Text(String(format: "%.1fs", engine.currentTime))
                    .font(.caption.monospacedDigit())
                    .foregroundColor(theme.textSecondary)
                
                // Add keyframe button
                Button(action: {
                    let newKf = AnimationEngine.KeyframeEntry(type: "posicion", time: engine.currentTime, easing: "linear")
                    engine.keyframes.append(newKf)
                    withAnimation(.spring(response: 0.4)) { showEasingPicker = true }
                }) {
                    Image(systemName: "plus.circle")
                        .font(.title3)
                        .foregroundColor(.accentColor)
                }
                .help("Agregar keyframe en la posicion actual")
            }
            .padding(.horizontal)
            
            // Clip selector
            Picker("Clip", selection: Binding(get: { engine.selectedClipName }, set: { engine.selectedClipName = $0 })) {
                ForEach(Array(engine.clips.keys.sorted()), id: \.self) { name in
                    Text(name).tag(name)
                }
            }
            .pickerStyle(.menu)
            .padding(.horizontal)
            
            // Timeline with keyframes
            GeometryReader { geo in
                let timelineWidth = geo.size.width - 32
                
                ZStack(alignment: .leading) {
                    // Background track with grid lines
                    RoundedRectangle(cornerRadius: 6)
                        .fill(theme.surfaceSecondary)
                        .frame(height: 24)
                    
                    // Grid lines every 0.5s
                    ForEach(0..<Int(currentClipDuration * 2), id: \.self) { i in
                        let t = Float(i) / 2.0
                        if t <= currentClipDuration {
                            let pos = currentClipDuration > 0 ? CGFloat(t / currentClipDuration) * timelineWidth : 0
                            Rectangle()
                                .fill(theme.surfaceSecondary)
                                .frame(width: 1, height: 24)
                                .offset(x: pos)
                        }
                    }
                    
                    // Current time indicator
                    Rectangle()
                        .fill(Color.accentColor)
                        .frame(width: 2, height: 32)
                        .offset(x: currentClipDuration > 0 ? CGFloat(engine.currentTime / currentClipDuration) * timelineWidth : 0)
                        .animation(.linear(duration: 0.016), value: engine.currentTime)
                    
                    // Keyframes
                    ForEach(engine.keyframes.filter { $0.modelName == engine.selectedClipName }) { kf in
                        let pos = currentClipDuration > 0 ? CGFloat(kf.time / currentClipDuration) * timelineWidth : 0
                        Circle()
                            .fill(selectedKfId == kf.id ? Color.accentColor : Color.blue.opacity(0.8))
                            .frame(width: selectedKfId == kf.id ? 14 : 10, height: selectedKfId == kf.id ? 14 : 10)
                            .shadow(color: selectedKfId == kf.id ? Color.accentColor.opacity(0.6) : .clear, radius: 4)
                            .offset(x: pos - (selectedKfId == kf.id ? 7 : 5))
                            .gesture(
                                DragGesture()
                                    .onChanged { value in
                                        let newTime = Float(value.location.x / timelineWidth) * currentClipDuration
                                        let clampedTime = max(0, min(newTime, currentClipDuration))
                                        engine.currentTime = clampedTime
                                        draggingKeyframeId = kf.id
                                        if let idx = engine.keyframes.firstIndex(where: { $0.id == kf.id }) {
                                            var updated = engine.keyframes[idx]
                                            updated.time = clampedTime
                                            engine.keyframes[idx] = updated
                                        }
                                    }
                                    .onEnded { _ in draggingKeyframeId = nil }
                            )
                            .onTapGesture {
                                withAnimation(.easeOut(duration: 0.2)) {
                                    selectedKfId = kf.id
                                    showEasingPicker.toggle()
                                }
                            }
                            .transition(.scale.combined(with: .opacity))
                            .animation(.spring(response: 0.3), value: engine.keyframes.count)
                    }
                }
                .padding(.horizontal, 16)
                
                // Easing picker for selected keyframe
                if showEasingPicker, let kfId = selectedKfId, let idx = engine.keyframes.firstIndex(where: { $0.id == kfId }) {
                    VStack(spacing: 8) {
                        Text("Curva de easing")
                            .font(.caption.bold())
                            .foregroundColor(theme.textSecondary)
                        
                        ForEach(EasingCurve.allCases, id: \.self) { curve in
                            Button(action: {
                                engine.keyframes[idx].easing = curve.rawValue
                                withAnimation(.easeOut(duration: 0.3)) { showEasingPicker = false; selectedKfId = nil }
                            }) {
                                Label(curve.rawValue, systemImage: curve.icon)
                                    .font(.subheadline)
                                    .foregroundColor(engine.keyframes[idx].easing == curve.rawValue ? .accentColor : theme.textPrimary)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(engine.keyframes[idx].easing == curve.rawValue ? Color.accentColor.opacity(0.2) : theme.surfaceSecondary)
                                    .cornerRadius(6)
                            }
                        }
                    }
                    .padding(12)
                    .background(theme.surface)
                    .cornerRadius(12)
                    .frame(width: 180)
                    .offset(x: 20, y: 40)
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .frame(height: 50)
            .padding(.horizontal)
            
            // Delete keyframe button
            if selectedKfId != nil {
                Button(action: {
                    if let idx = engine.keyframes.firstIndex(where: { $0.id == selectedKfId }) {
                        withAnimation(.easeOut(duration: 0.2)) {
                            let _ = engine.keyframes.remove(at: idx)
                            selectedKfId = nil
                            showEasingPicker = false
                        }
                    }
                }) {
                    Label("Eliminar keyframe", systemImage: "trash")
                        .font(.caption)
                        .foregroundColor(.red)
                }
                .padding(.bottom, 8)
                .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.vertical, 8)
    }
}