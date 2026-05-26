import SwiftUI
import Satin
import OSLog

private let logger = Logger(subsystem: "com.appforgestudio", category: "TransformationGizmoView")
/// Gizmo de transformación 3D con ejes X, Y, Z para mover, rotar y escalar
struct TransformationGizmoView: View {
    @Binding var position: SIMD3<Float>
    @Binding var rotation: SIMD3<Float>
    @Binding var scale: SIMD3<Float>
    @State private var activeAxis: Axis = .x
    @State private var mode: TransformMode = .translate
    
    var body: some View {
        VStack(spacing: 12) {
            // Selector de modo
            Picker("Mode", selection: $mode) {
                ForEach(TransformMode.allCases) { m in
                    Image(systemName: m.icon).tag(m)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 180)
            
            // Ejes
            HStack(spacing: 20) {
                AxisButton(axis: .x, color: .red, isActive: activeAxis == .x) { activeAxis = .x }
                AxisButton(axis: .y, color: .green, isActive: activeAxis == .y) { activeAxis = .y }
                AxisButton(axis: .z, color: .blue, isActive: activeAxis == .z) { activeAxis = .z }
            }
            
            // Sliders de valor
            Group {
                switch mode {
                case .translate:
                    TranslateSliders(position: $position, activeAxis: $activeAxis)
                case .rotate:
                    RotateSliders(rotation: $rotation, activeAxis: $activeAxis)
                case .scale:
                    ScaleSliders(scale: $scale, activeAxis: $activeAxis)
                }
            }
            .padding(.horizontal)
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Supporting Views

struct AxisButton: View {
    let axis: Axis
    let color: Color
    let isActive: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(axis.rawValue.uppercased())
                .font(.caption.weight(.bold))
                .frame(width: 36, height: 36)
                .background(isActive ? color.opacity(0.3) : color.opacity(0.1))
                .foregroundColor(color)
                .clipShape(Circle())
                .overlay(Circle().stroke(color, lineWidth: isActive ? 2 : 1))
        }
    }
}

struct TranslateSliders: View {
    @Binding var position: SIMD3<Float>
    @Binding var activeAxis: Axis
    
    var body: some View {
        VStack(spacing: 8) {
            if activeAxis == .x || activeAxis == .all {
                LabelledSlider(label: "X", value: $position.x, range: -10...10, color: .red)
            }
            if activeAxis == .y || activeAxis == .all {
                LabelledSlider(label: "Y", value: $position.y, range: -10...10, color: .green)
            }
            if activeAxis == .z || activeAxis == .all {
                LabelledSlider(label: "Z", value: $position.z, range: -10...10, color: .blue)
            }
        }
    }
}

struct RotateSliders: View {
    @Binding var rotation: SIMD3<Float>
    @Binding var activeAxis: Axis
    
    var body: some View {
        VStack(spacing: 8) {
            if activeAxis == .x || activeAxis == .all {
                LabelledSlider(label: "X", value: $rotation.x, range: -.pi...(.pi), color: .red)
            }
            if activeAxis == .y || activeAxis == .all {
                LabelledSlider(label: "Y", value: $rotation.y, range: -.pi...(.pi), color: .green)
            }
            if activeAxis == .z || activeAxis == .all {
                LabelledSlider(label: "Z", value: $rotation.z, range: -.pi...(.pi), color: .blue)
            }
        }
    }
}

struct ScaleSliders: View {
    @Binding var scale: SIMD3<Float>
    @Binding var activeAxis: Axis
    
    var body: some View {
        VStack(spacing: 8) {
            if activeAxis == .x || activeAxis == .all {
                LabelledSlider(label: "X", value: $scale.x, range: 0.01...10, color: .red)
            }
            if activeAxis == .y || activeAxis == .all {
                LabelledSlider(label: "Y", value: $scale.y, range: 0.01...10, color: .green)
            }
            if activeAxis == .z || activeAxis == .all {
                LabelledSlider(label: "Z", value: $scale.z, range: 0.01...10, color: .blue)
            }
        }
    }
}

struct LabelledSlider: View {
    let label: String
    @Binding var value: Float
    let range: ClosedRange<Float>
    let color: Color
    
    var body: some View {
        HStack {
            Text(label)
                .font(.caption.weight(.bold))
                .foregroundColor(color)
                .frame(width: 20)
            Slider(value: $value, in: range)
                .tint(color)
            Text(String(format: "%.2f", value))
                .font(.caption2.monospaced())
                .frame(width: 50, alignment: .trailing)
        }
    }
}

// MARK: - Enums

enum Axis: String, CaseIterable {
    case x, y, z, all
}

enum TransformMode: String, CaseIterable, Identifiable {
    case translate, rotate, scale
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .translate: return "arrow.up.and.down.and.arrow.left.and.right"
        case .rotate:    return "arrow.triangle.2.circlepath"
        case .scale:     return "arrow.up.left.and.down.right.magnifyingglass"
        }
    }
}
