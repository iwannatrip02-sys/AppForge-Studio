import SwiftUI
import OSLog

private let logger = Logger(subsystem: "com.appforgestudio", category: "CADSketchView")

struct CADSketchView: View {
    @StateObject var sketchEngine: CADSketchEngine
    @State private var selectedTool: SketchTool = .line
    @State private var showConstraints: Bool = false
    @State private var extrudeDistance: Float = 0.1
    @State private var animatePoints: Bool = false
    @State private var pencilPressure: CGFloat = 0
    @Binding var meshResult: Mesh?
    @EnvironmentObject var themeManager: ThemeManager

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            canvas
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: sketchEngine.points.map { $0.position })
            bottomBar
        }
        .sheet(isPresented: $showConstraints) {
            NavigationView {
                List {
                    ForEach(Array(sketchEngine.constraintManager.constraints.enumerated()), id: \.element.id) { i, c in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(c.label).font(.caption)
                                Text(c.type.rawValue).font(.caption2).foregroundColor(.secondary)
                            }
                            Spacer()
                            if c.isActive {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                    .font(.caption)
                            }
                        }
                    }
                    .onDelete { idx in
                        for i in idx { sketchEngine.constraintManager.removeConstraint(at: i) }
                    }
                }
                .navigationTitle("Constraints")
                .toolbar { EditButton() }
            }
        }
    }

    private var toolbar: some View {
        HStack {
            Button(action: {
                sketchEngine.undoLastOperation()
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }) {
                Image(systemName: "arrow.uturn.backward")
                    .font(.system(size: 11))
                    .foregroundColor(themeManager.currentTheme.textPrimary)
            }
            .disabled(!sketchEngine.historyTree.canUndo)

            Button(action: {
                sketchEngine.redoLastOperation()
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }) {
                Image(systemName: "arrow.uturn.forward")
                    .font(.system(size: 11))
                    .foregroundColor(themeManager.currentTheme.textPrimary)
            }
            .disabled(!sketchEngine.historyTree.canRedo)

            Rectangle()
                .fill(themeManager.currentTheme.border)
                .frame(width: 1, height: 16)
                .padding(.horizontal, 2)

            ForEach(SketchTool.allCases, id: \.self) { tool in
                Button(action: { selectedTool = tool }) {
                    Text(tool.rawValue)
                        .font(.system(size: 11))
                        .padding(.horizontal, 6).padding(.vertical, 3)
                        .background(selectedTool == tool ? Color.blue : themeManager.currentTheme.surfaceSecondary)
                        .foregroundColor(themeManager.currentTheme.textPrimary).cornerRadius(5)
                }
            }
            Spacer()

            Button(action: {
                sketchEngine.pencilMode.toggle()
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }) {
                Image(systemName: sketchEngine.pencilMode ? "pencil.tip" : "pencil")
                    .font(.system(size: 13))
                    .foregroundColor(sketchEngine.pencilMode ? .blue : themeManager.currentTheme.textPrimary)
            }

            Button(action: {
                sketchEngine.resolvePendingConstraints()
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            }) {
                Text("Resolve")
                    .font(.system(size: 10))
                    .padding(.horizontal, 6).padding(.vertical, 3)
                    .background(Color.green.opacity(0.2))
                    .foregroundColor(.green)
                    .cornerRadius(5)
            }
            Button(action: { sketchEngine.clearAll() }) {
                Image(systemName: "trash").foregroundColor(.red)
            }
        }
        .padding(.horizontal, 6).padding(.vertical, 3)
        .background(themeManager.currentTheme.surface)
    }

    private var canvas: some View {
        GeometryReader { geo in
            if sketchEngine.pencilMode {
                PencilSketchView(
                    isPencilMode: $sketchEngine.pencilMode,
                    currentPressure: $pencilPressure,
                    sketchEngine: sketchEngine
                )
            } else {
                ZStack {
                    SketchGridView(gridSize: sketchEngine.gridSize, canvasSize: geo.size)
                    ForEach(sketchEngine.entities, id: \.id) { entity in
                        EntityView2(entity: entity, points: sketchEngine.points)
                    }
                }
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onEnded { value in
                            let pos = SIMD2<Float>(Float(value.location.x / 200 - 2), Float(2 - value.location.y / 200))
                            let snapped = sketchEngine.snapToGrid(pos)
                            let pt = SketchPoint(position: snapped)
                            sketchEngine.addPoint(pt)

                            switch selectedTool {
                            case .line:
                                if let last = sketchEngine.entities.compactMap({
                                    if case .line(let l) = $0 { return l }
                                    return nil
                                }).last {
                                    sketchEngine.entities.append(.line(SketchLine(start: last.end, end: pt.id)))
                                } else {
                                    sketchEngine.entities.append(.line(SketchLine(start: pt.id, end: pt.id)))
                                }
                            case .circle:
                                sketchEngine.entities.append(.circle(SketchCircle(center: pt.id, radius: 0.05)))
                            case .rectangle:
                                sketchEngine.entities.append(.rectangle(SketchRectangle(origin: pt.id, size: SIMD2<Float>(0.1, 0.1))))
                            case .arc:
                                sketchEngine.entities.append(.arc(SketchArc(center: pt.id, radius: 0.05, startAngle: 0, endAngle: 3.14159)))
                            case .point:
                                break
                            case .select:
                                break
                            }
                        }
                )
            }
        }
    }

    private var bottomBar: some View {
        HStack {
            Text("Extrusion:").font(.caption)
            Slider(value: $extrudeDistance, in: 0.01...1.0).frame(width: 100)
            Text(String(format: "%.2f", extrudeDistance)).font(.caption).frame(width: 35)

            if sketchEngine.pencilMode {
                Text("Pressure: \(String(format: "%.1f", pencilPressure * 100))%")
                    .font(.system(size: 9))
                    .foregroundColor(pencilPressure > 0.5 ? .blue : themeManager.currentTheme.textSecondary)
                    .padding(.leading, 8)
            }
            Spacer()

            VStack(alignment: .trailing, spacing: 1) {
                Text("Constraints: \(sketchEngine.constraintManager.activeConstraintCount)/\(sketchEngine.constraintManager.constraintCount)")
                    .font(.system(size: 9))
                    .foregroundColor(themeManager.currentTheme.textSecondary)
                if sketchEngine.constraintManager.constraintCount > 0 {
                    HStack(spacing: 2) {
                        Circle()
                            .fill(sketchEngine.solverConverged ? Color.green : Color.orange)
                            .frame(width: 5, height: 5)
                        Text(sketchEngine.solverConverged ? "Converged" : "Not resolved")
                            .font(.system(size: 8))
                            .foregroundColor(themeManager.currentTheme.textSecondary)
                    }
                }
            }

            Spacer().frame(width: 8)

            Button("Extruir") {
                meshResult = sketchEngine.extrudeSketch(distance: extrudeDistance)
            }.buttonStyle(.borderedProminent).controlSize(.small)
            Button("Constraints") { showConstraints.toggle() }.controlSize(.small)
        }
        .padding(.horizontal, 8).padding(.vertical, 3)
        .background(themeManager.currentTheme.surface)
    }
}

struct SketchGridView: View {
    let gridSize: Float
    let canvasSize: CGSize
    @EnvironmentObject var themeManager: ThemeManager
    var body: some View {
        Canvas { ctx, size in
            let sp = CGFloat(gridSize * 200)
            guard sp > 3 else { return }
            for x in stride(from: 0, through: size.width, by: sp) {
                var p = Path(); p.move(to: CGPoint(x: x, y: 0)); p.addLine(to: CGPoint(x: x, y: size.height))
                ctx.stroke(p, with: .color(themeManager.currentTheme.border), lineWidth: 0.5)
            }
            for y in stride(from: 0, through: size.height, by: sp) {
                var p = Path(); p.move(to: CGPoint(x: 0, y: y)); p.addLine(to: CGPoint(x: size.width, y: y))
                ctx.stroke(p, with: .color(themeManager.currentTheme.border), lineWidth: 0.5)
            }
        }
    }
}

struct EntityView2: View {
    let entity: SketchEntity
    let points: [SketchPoint]
    @EnvironmentObject var themeManager: ThemeManager
    var body: some View {
        Canvas { ctx, size in
            func sc(_ p: SIMD2<Float>) -> CGPoint {
                CGPoint(x: CGFloat((p.x + 2) * 200), y: CGFloat((2 - p.y) * 200))
            }
            switch entity {
            case .point(let p):
                let cp = sc(p.position)
                ctx.fill(Path(ellipseIn: CGRect(x: cp.x-3, y: cp.y-3, width: 6, height: 6)), with: .color(themeManager.currentTheme.textPrimary))
            case .line(let l):
                if let s = points.first(where: { $0.id == l.start }), let e = points.first(where: { $0.id == l.end }) {
                    var p = Path(); p.move(to: sc(s.position)); p.addLine(to: sc(e.position))
                    ctx.stroke(p, with: .color(.cyan), lineWidth: 1.5)
                }
            case .circle(let c):
                if let cp = points.first(where: { $0.id == c.center }) {
                    let cpt = sc(cp.position); let r = CGFloat(c.radius * 200)
                    ctx.stroke(Path(ellipseIn: CGRect(x: cpt.x-r, y: cpt.y-r, width: r*2, height: r*2)), with: .color(.cyan), lineWidth: 1.5)
                }
            case .rectangle(let r):
                if let op = points.first(where: { $0.id == r.origin }) {
                    let opt = sc(op.position); let sz = CGSize(width: CGFloat(r.size.x*200), height: CGFloat(r.size.y*200))
                    ctx.stroke(Path(CGRect(origin: opt, size: sz)), with: .color(.cyan), lineWidth: 1.5)
                }
            case .arc(let a):
                if let cp = points.first(where: { $0.id == a.center }) {
                    let cpt = sc(cp.position); let r = CGFloat(a.radius * 200)
                    var p = Path()
                    p.addArc(center: cpt, radius: r, startAngle: .degrees(Double(a.startAngle)), endAngle: .degrees(Double(a.endAngle)), clockwise: false)
                    ctx.stroke(p, with: .color(.cyan), lineWidth: 1.5)
                }
            }
        }
    }
}
