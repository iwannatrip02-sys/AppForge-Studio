import SwiftUI
import simd
import CoreGraphics

// MARK: - Proyección cámara → pantalla

/// Utilidad para proyectar puntos 3D a coordenadas de pantalla 2D
struct ViewportProjector {
    let viewMatrix: simd_float4x4
    let projectionMatrix: simd_float4x4
    let viewportSize: CGSize

    /// Proyecta un punto 3D del mundo a coordenadas de pantalla.
    /// Retorna nil si el punto está detrás de la cámara.
    func project(_ worldPoint: SIMD3<Float>) -> CGPoint? {
        let world = SIMD4<Float>(worldPoint.x, worldPoint.y, worldPoint.z, 1)
        let clip = simd_mul(projectionMatrix, simd_mul(viewMatrix, world))
        guard clip.w > 0.0001 else { return nil }
        let ndcX = clip.x / clip.w
        let ndcY = clip.y / clip.w
        let screenX = (ndcX + 1) * 0.5 * viewportSize.width
        let screenY = (1 - ndcY) * 0.5 * viewportSize.height
        return CGPoint(x: CGFloat(screenX), y: CGFloat(screenY))
    }
}

// MARK: - Overlay de cotas 3D

/// Renderiza cotas 3D como líneas + texto en espacio pantalla.
/// Estilo Shapr3D: líneas finas, color ámbar, texto con fondo semitransparente,
/// líneas de extensión desde los puntos medidos.
struct DimensionOverlayView: View {
    let annotations: [DimensionAnnotation]
    let projector: ViewportProjector
    let scale: CGFloat  // escala de UI para tamaño de fuente/touch targets

    var body: some View {
        Canvas { context, size in
            for annotation in annotations {
                drawDimension(annotation, in: &context, size: size)
            }
        }
        .allowsHitTesting(false)
    }

    // MARK: - Dibujo por tipo de cota

    private func drawDimension(_ ann: DimensionAnnotation,
                                in context: inout GraphicsContext,
                                size: CGSize) {
        switch ann.type {
        case .linear, .aligned:
            drawLinearDimension(ann, in: &context, size: size)
        case .radius:
            drawRadiusDimension(ann, in: &context, size: size)
        case .diameter:
            drawDiameterDimension(ann, in: &context, size: size)
        case .angle:
            drawAngleDimension(ann, in: &context, size: size)
        }
    }

    // MARK: - Cota lineal

    private func drawLinearDimension(_ ann: DimensionAnnotation,
                                      in context: inout GraphicsContext,
                                      size: CGSize) {
        guard ann.anchorPoints.count >= 2,
              let p0 = projector.project(ann.anchorPoints[0]),
              let p1 = projector.project(ann.anchorPoints[1]) else { return }

        let mid = CGPoint(x: (p0.x + p1.x) / 2, y: (p0.y + p1.y) / 2)
        let dir = CGPoint(x: p1.x - p0.x, y: p1.y - p0.y)
        let len = sqrt(dir.x * dir.x + dir.y * dir.y)
        guard len > 1 else { return }

        let normal = CGPoint(x: -dir.y / len, y: dir.x / len)

        // Líneas de extensión (desde puntos hasta la línea de cota)
        let extEnd0 = CGPoint(x: p0.x + normal.x * ann.screenOffset,
                               y: p0.y + normal.y * ann.screenOffset)
        let extEnd1 = CGPoint(x: p1.x + normal.x * ann.screenOffset,
                               y: p1.y + normal.y * ann.screenOffset)

        let extPath = Path { path in
            // Línea de extensión 0
            path.move(to: p0)
            path.addLine(to: extEnd0)
            // Línea de extensión 1
            path.move(to: p1)
            path.addLine(to: extEnd1)
            // Línea de cota
            path.move(to: extEnd0)
            path.addLine(to: extEnd1)
            // Ticks en extremos
            let tickLen: CGFloat = 8
            path.move(to: CGPoint(x: extEnd0.x - normal.x * tickLen, y: extEnd0.y - normal.y * tickLen))
            path.addLine(to: CGPoint(x: extEnd0.x + normal.x * tickLen, y: extEnd0.y + normal.y * tickLen))
            path.move(to: CGPoint(x: extEnd1.x - normal.x * tickLen, y: extEnd1.y - normal.y * tickLen))
            path.addLine(to: CGPoint(x: extEnd1.x + normal.x * tickLen, y: extEnd1.y + normal.y * tickLen))
        }

        context.stroke(extPath,
                       with: .color(Color(red: 1, green: 0.48, blue: 0.27)),
                       style: StrokeStyle(lineWidth: 1.5, lineCap: .round))

        // Etiqueta de texto en el punto medio de la línea de cota
        let labelPos = CGPoint(x: mid.x + normal.x * ann.screenOffset,
                                y: mid.y + normal.y * ann.screenOffset)
        drawLabel(ann.label, at: labelPos, in: &context)
    }

    // MARK: - Cota de radio

    private func drawRadiusDimension(_ ann: DimensionAnnotation,
                                      in context: inout GraphicsContext,
                                      size: CGSize) {
        guard ann.anchorPoints.count >= 2,
              let center = projector.project(ann.anchorPoints[0]),
              let edge = projector.project(ann.anchorPoints[1]) else { return }

        let dx = edge.x - center.x
        let dy = edge.y - center.y
        let radius = sqrt(dx * dx + dy * dy)
        guard radius > 1 else { return }

        // Línea desde el centro hasta el borde
        let linePath = Path { path in
            path.move(to: center)
            path.addLine(to: edge)
            // Pequeño tick en el centro
            path.addEllipse(in: CGRect(x: center.x - 3, y: center.y - 3, width: 6, height: 6))
        }

        context.stroke(linePath,
                       with: .color(Color(red: 0.3, green: 0.7, blue: 1.0)),
                       style: StrokeStyle(lineWidth: 1.5, lineCap: .round))

        // Etiqueta "R x.xx" en el punto medio de la línea
        let mid = CGPoint(x: (center.x + edge.x) / 2, y: (center.y + edge.y) / 2)
        drawLabel(ann.label, at: mid, in: &context)
    }

    // MARK: - Cota de diámetro

    private func drawDiameterDimension(_ ann: DimensionAnnotation,
                                        in context: inout GraphicsContext,
                                        size: CGSize) {
        guard ann.anchorPoints.count >= 2,
              let center = projector.project(ann.anchorPoints[0]),
              let edge = projector.project(ann.anchorPoints[1]) else { return }

        let dx = edge.x - center.x
        let dy = edge.y - center.y
        let radius = sqrt(dx * dx + dy * dy)
        guard radius > 1 else { return }

        // Línea de diámetro (atraviesa todo el círculo)
        let angle = atan2(dy, dx)
        let p1 = CGPoint(x: center.x + cos(angle) * radius,
                          y: center.y + sin(angle) * radius)
        let p2 = CGPoint(x: center.x - cos(angle) * radius,
                          y: center.y - sin(angle) * radius)

        let linePath = Path { path in
            path.move(to: p1)
            path.addLine(to: p2)
        }

        context.stroke(linePath,
                       with: .color(Color(red: 0.3, green: 0.7, blue: 1.0)),
                       style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))

        drawLabel(ann.label,
                  at: CGPoint(x: center.x + 15, y: center.y - 15),
                  in: &context)
    }

    // MARK: - Cota de ángulo

    private func drawAngleDimension(_ ann: DimensionAnnotation,
                                     in context: inout GraphicsContext,
                                     size: CGSize) {
        guard ann.anchorPoints.count >= 3,
              let vertex = projector.project(ann.anchorPoints[0]),
              let pA = projector.project(ann.anchorPoints[1]),
              let pB = projector.project(ann.anchorPoints[2]) else { return }

        let dA = sqrt(pow(pA.x - vertex.x, 2) + pow(pA.y - vertex.y, 2))
        let dB = sqrt(pow(pB.x - vertex.x, 2) + pow(pB.y - vertex.y, 2))
        let arcRadius: CGFloat = min(30, min(dA, dB) * 0.5)

        let angleA = atan2(pA.y - vertex.y, pA.x - vertex.x)
        let angleB = atan2(pB.y - vertex.y, pB.x - vertex.x)

        let arcPath = Path { path in
            path.addArc(center: vertex, radius: arcRadius,
                        startAngle: Angle(radians: Double(min(angleA, angleB))),
                        endAngle: Angle(radians: Double(max(angleA, angleB))),
                        clockwise: false)
        }

        context.stroke(arcPath,
                       with: .color(Color(red: 0.3, green: 1.0, blue: 0.6)),
                       style: StrokeStyle(lineWidth: 1.5))

        let midAngle = (angleA + angleB) / 2
        let labelPos = CGPoint(x: vertex.x + cos(midAngle) * (arcRadius + 25),
                                y: vertex.y + sin(midAngle) * (arcRadius + 25))
        drawLabel(ann.label, at: labelPos, in: &context)
    }

    // MARK: - Etiqueta de texto

    private func drawLabel(_ text: String, at position: CGPoint,
                            in context: inout GraphicsContext) {
        let styled = Text(text)
            .font(.system(size: 11, weight: .medium, design: .monospaced))
            .foregroundColor(Color(red: 1, green: 0.48, blue: 0.27))
        let resolved = context.resolve(styled)
        let textSize = resolved.measure(in: CGSize(width: 200, height: 30))

        // Fondo semitransparente para legibilidad
        let bgRect = CGRect(x: position.x - textSize.width / 2 - 4,
                            y: position.y - textSize.height / 2 - 2,
                            width: textSize.width + 8,
                            height: textSize.height + 4)

        context.fill(Path(roundedRect: bgRect, cornerRadius: 3),
                      with: .color(Color(white: 0.1, opacity: 0.85)))

        // anchor .center (default) alinea el texto con el fondo centrado en position
        context.draw(resolved, at: position)
    }
}

// MARK: - Vista contenedora con proyección

/// Overlay completo de mediciones que se monta sobre el viewport 3D.
/// Lee la cámara desde CanvasViewModel para proyectar puntos 3D → pantalla.
struct MeasurementOverlay: View {
    @ObservedObject var dimensionManager: DimensionManager
    @ObservedObject var canvasVM: CanvasViewModel

    var body: some View {
        GeometryReader { geometry in
            let projector = ViewportProjector(
                viewMatrix: canvasVM.viewMatrix,
                projectionMatrix: canvasVM.projectionMatrix(for: geometry.size),
                viewportSize: geometry.size
            )
            DimensionOverlayView(
                annotations: dimensionManager.annotations,
                projector: projector,
                scale: geometry.size.width / 768  // normalizado a iPad
            )
        }
        .allowsHitTesting(false)
    }
}
