import Foundation
import simd

// MARK: - Grid del plano de trabajo

/// Genera una malla de grilla translúcida sobre el plano de trabajo activo.
/// Estilo Shapr3D: líneas finas, color gris acero, líneas mayores cada 10 unidades,
/// líneas menores cada 1 unidad. La grilla sigue la orientación del plano.
///
/// Se regenera cuando cambia el plano de trabajo o el paso de grid.
struct WorkPlaneGrid {
    /// Tamaño total de la grilla en unidades de mundo (mm internos)
    var extent: Float = 20
    /// Espaciado entre líneas mayores
    var majorStep: Float = 10
    /// Espaciado entre líneas menores
    var minorStep: Float = 1
    /// Opacidad de la grilla (0 = invisible, 1 = opaca)
    var opacity: Float = 0.25
    /// Color de líneas mayores
    var majorColor: SIMD4<Float> = SIMD4<Float>(0.5, 0.52, 0.58, 0.35)
    /// Color de líneas menores
    var minorColor: SIMD4<Float> = SIMD4<Float>(0.35, 0.37, 0.42, 0.18)

    /// Genera la malla de la grilla en el plano de trabajo dado.
    /// - Parameter plane: plano de trabajo (origin, u, v, normal)
    /// - Returns: Mesh con las líneas de la grilla (tubos finos)
    func generate(in plane: SketchController.WorkPlane) -> Mesh {
        var vertices: [Vertex] = []
        var indices: [UInt32] = []
        let halfExtent = extent / 2
        let lineRadius: Float = 0.003  // tubos MUY finos, casi líneas

        // Generar líneas en dirección U (paralelas al eje V)
        var uPos = -halfExtent
        while uPos <= halfExtent {
            let isMajor = abs(uPos.truncatingRemainder(dividingBy: majorStep)) < 0.001
                || abs(uPos) < 0.001
            let step = isMajor ? majorStep : minorStep
            if !isMajor && abs(uPos.truncatingRemainder(dividingBy: majorStep)) < step { uPos += step; continue }

            let start = plane.origin + plane.u * uPos + plane.v * (-halfExtent)
            let end   = plane.origin + plane.u * uPos + plane.v * halfExtent
            GizmoBuilder.appendTube(polyline: [start, end], radius: isMajor ? lineRadius * 1.5 : lineRadius,
                                    to: &vertices, indices: &indices)
            uPos += step
        }

        // Generar líneas en dirección V (paralelas al eje U)
        var vPos = -halfExtent
        while vPos <= halfExtent {
            let isMajor = abs(vPos.truncatingRemainder(dividingBy: majorStep)) < 0.001
                || abs(vPos) < 0.001
            let step = isMajor ? majorStep : minorStep
            if !isMajor && abs(vPos.truncatingRemainder(dividingBy: majorStep)) < step { vPos += step; continue }

            let start = plane.origin + plane.u * (-halfExtent) + plane.v * vPos
            let end   = plane.origin + plane.u * halfExtent + plane.v * vPos
            GizmoBuilder.appendTube(polyline: [start, end], radius: isMajor ? lineRadius * 1.5 : lineRadius,
                                    to: &vertices, indices: &indices)
            vPos += step
        }

        // Cruz en el origen (ejes U y V)
        let origin = plane.origin
        let axisLen = halfExtent * 0.3
        // Eje U (rojo suave)
        let uEnd = origin + plane.u * axisLen
        GizmoBuilder.appendTube(polyline: [origin, uEnd], radius: lineRadius * 2.5,
                                to: &vertices, indices: &indices)
        // Eje V (verde suave)
        let vEnd = origin + plane.v * axisLen
        GizmoBuilder.appendTube(polyline: [origin, vEnd], radius: lineRadius * 2.5,
                                to: &vertices, indices: &indices)

        return Mesh(vertices: vertices, indices: indices)
    }

    /// Versión simplificada: solo líneas mayores, más rápido de regenerar
    func generateFast(in plane: SketchController.WorkPlane) -> Mesh {
        var fast = self
        fast.minorStep = majorStep  // solo mayores
        fast.extent = extent * 0.7
        return fast.generate(in: plane)
    }
}

// MARK: - Snap points visualization

/// Genera marcadores visuales para puntos de snap (endpoints, midpoints, centros, grid).
struct SnapPointsOverlay {

    /// Radio de los marcadores de snap en unidades de mundo
    var markerRadius: Float = 0.04

    /// Genera malla de marcadores para los puntos de snap dados.
    func generate(for points: [SnapPoint], on plane: SketchController.WorkPlane) -> Mesh? {
        guard !points.isEmpty else { return nil }
        var vertices: [Vertex] = []
        var indices: [UInt32] = []

        for point in points {
            let p = point.position
            // Pequeño diamante/cruz en cada snap point
            let s = markerRadius
            let u = plane.u * s
            let v = plane.v * s
            // Cruz en el plano: líneas en dirección U y V
            GizmoBuilder.appendTube(polyline: [p - u, p + u], radius: s * 0.4,
                                    to: &vertices, indices: &indices)
            GizmoBuilder.appendTube(polyline: [p - v, p + v], radius: s * 0.4,
                                    to: &vertices, indices: &indices)
        }

        return vertices.isEmpty ? nil : Mesh(vertices: vertices, indices: indices)
    }
}

// MARK: - Extensión para Model (overlay de grilla)

extension Model {
    /// Crea un modelo de overlay para la grilla del plano de trabajo.
    /// Los overlays usan el prefijo "__" para que no sean tocables ni exportables.
    static func workPlaneGrid(name: String = "__workPlaneGrid",
                               plane: SketchController.WorkPlane,
                               step: Float = 10) -> Model {
        let grid = WorkPlaneGrid(majorStep: step, minorStep: 1)
        let mesh = grid.generate(in: plane)
        let model = Model(name: name)
        model.meshes = [mesh]
        model.color = SIMD4<Float>(0.5, 0.52, 0.58, 0.35)
        model.isVisible = true
        return model
    }

    /// Crea un modelo de overlay para los snap points.
    static func snapPointsOverlay(name: String = "__snapPoints",
                                   points: [SnapPoint],
                                   plane: SketchController.WorkPlane) -> Model? {
        let overlay = SnapPointsOverlay()
        guard let mesh = overlay.generate(for: points, on: plane) else { return nil }
        let model = Model(name: name)
        model.meshes = [mesh]
        model.color = SIMD4<Float>(0.3, 0.7, 1.0, 0.9)  // azul snap
        model.isVisible = true
        return model
    }
}
