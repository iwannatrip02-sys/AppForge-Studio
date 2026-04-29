import SwiftUI

struct AnimationView: View {
    @ObservedObject var engine: AnimationEngine
    
    var body: some View {
        VStack(spacing: 12) {
            // Controls
            HStack(spacing: 16) {
                Button(action: { engine.isPlaying.toggle() }) {
                    Image(systemName: engine.isPlaying ? "pause.fill" : "play.fill")
                        .font(.title2)
                        .foregroundColor(.white)
                }
                
                Slider(value: $engine.currentTime, in: 0...currentClipDuration, step: 0.016) {
                    Text("Tiempo")
                }
                .accentColor(.blue)
                
                Text(String(format: "%.1fs", engine.currentTime))
                    .font(.caption.monospacedDigit())
                    .foregroundColor(.gray)
            }
            .padding(.horizontal)
            
            // Clip selector
            Picker("Clip", selection: $engine.selectedClipName) {
                ForEach(Array(engine.clips.keys.sorted()), id: \.self) { name in
                    Text(name).tag(name)
                }
            }
            .pickerStyle(.menu)
            .padding(.horizontal)
            
            // Timeline with keyframes
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: 20)
                
                ForEach(engine.keyframes.filter { $0.modelName == engine.selectedClipName }) { kf in
                    let pos = currentClipDuration > 0 ? CGFloat(kf.time / currentClipDuration) : 0
                    Circle()
                        .fill(Color.accentColor)
                        .frame(width: 8, height: 8)
                        .offset(x: pos * (UIScreen.main.bounds.width - 64) - 4)
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
        .background(Color.black.opacity(0.5))
        .cornerRadius(12)
    }
    
    private var currentClipDuration: Float {
        guard let clip = engine.clips[engine.selectedClipName] else { return 0 }
        return clip.duration
    }
}
