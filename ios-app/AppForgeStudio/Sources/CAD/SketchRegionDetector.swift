import Foundation
import simd

// MARK: - Detector de Regiones Cerradas en Sketch 2D

/// Analiza un conjunto de entidades de sketch y detecta regiones cerradas
/// (ciclos en el grafo de líneas). Cada región es un polígono que puede
/// extruirse directamente — el "sombreado mágico" de Shapr3D.
///
/// Algoritmo:
/// 1. Construir grafo no-dirigido de segmentos de línea
/// 2. Encontrar todos los ciclos mínimos (face cycles de planar graph)
/// 3. Para cada ciclo, generar polígono ordenado
/// 4. El polígono se usa para: (a) mesh de relleno sombreado, (b) Wire OCCT para extrusión
struct SketchRegionDetector {

    /// Una región cerrada detectada: polígono ordenado + área + centroide
    struct ClosedRegion: Identifiable {
        let id: UUID
        /// Vértices en orden ( antihorario = exterior, horario = agujero )
        var vertices: [SIMD2<Float>]
        /// Área de la región (positiva = contorno exterior)
        var area: Float
        /// Centroide de la región
        var centroid: SIMD2<Float>
        /// Si es un agujero (área negativa → dentro de otra región)
        var isHole: Bool

        init(id: UUID = UUID(), vertices: [SIMD2<Float>]) {
            self.id = id
            self.vertices = vertices
            self.area = SketchRegionDetector.polygonArea(vertices)
            self.isHole = self.area < 0
            self.centroid = SketchRegionDetector.polygonCentroid(vertices)
        }
    }

    // MARK: - API Pública

    // NOTA Fase 1: detectRegions(in: [Entity]) fue eliminado — la detección de
    // regiones vive ahora en SketchKernel.RegionFinder (arreglo plano real con
    // particion en cruces). Aquí quedan solo ClosedRegion + el render 3D del
    // relleno (fillMesh/overlay), que consumen los polígonos del kernel.

    /// Genera una malla de relleno para las regiones (triángulos semitransparentes
    /// que se renderizan sobre el plano de sketch para mostrar "esto es un sólido potencial")
    static func fillMesh(for regions: [ClosedRegion],
                          on plane: SketchController.WorkPlane,
                          color: SIMD4<Float> = SIMD4<Float>(1.0, 0.48, 0.27, 0.18)) -> Mesh? {
        var vertices: [Vertex] = []
        var indices: [UInt32] = []
        let offset = plane.normal * 0.001  // evitar z-fighting con el plano

        for region in regions where !region.isHole && region.vertices.count >= 3 {
            let base = UInt32(vertices.count)
            // Triangulación por abanico desde el centroide
            let c3 = plane.origin + plane.u * region.centroid.x + plane.v * region.centroid.y + offset
            vertices.append(Vertex(position: c3, normal: plane.normal, uv: .zero))

            for v in region.vertices {
                let w3 = plane.origin + plane.u * v.x + plane.v * v.y + offset
                vertices.append(Vertex(position: w3, normal: plane.normal, uv: .zero))
            }

            for i in 0..<region.vertices.count {
                indices.append(base)
                indices.append(base + UInt32(i + 1))
                indices.append(base + UInt32((i + 1) % region.vertices.count + 1))
            }
        }

        return vertices.count > 3 ? Mesh(vertices: vertices, indices: indices) : nil
    }

    // ALGORITMO DE DETECCIÓN DE CICLOS ELIMINADO (auditoría 2026-07-25).
    //
    // `findClosedRegions` + `traceCycle` eran una SEGUNDA implementación de
    // detección de regiones —grafo con snap por tolerancia y recorrido del giro
    // más a la derecha— que ya nadie llamaba: la nota de arriba dice que la
    // detección pasó a `SketchKernel.RegionFinder`, pero los cuerpos se
    // quedaron aquí, privados y muertos.
    //
    // Es el patrón de podredumbre documentado del repo: código paralelo latente
    // que una sesión futura re-cablea sin saber cuál es el canónico. Y este era
    // peor que inútil: usaba tolerancia ABSOLUTA (0.01) y un límite de 500
    // pasos, así que habría fallado justo donde el kernel acierta.
    //
    // Lo que queda en este archivo es lo único vivo: `ClosedRegion` como
    // portador de datos y `fillMesh` como render del relleno, ambos alimentados
    // por los polígonos del kernel.

    // MARK: - Utilidades geométricas

    /// Área de un polígono (fórmula del cordón de zapato).
    /// Positiva = antihorario (contorno exterior), negativa = horario (agujero).
    static func polygonArea(_ vertices: [SIMD2<Float>]) -> Float {
        guard vertices.count >= 3 else { return 0 }
        var area: Float = 0
        for i in 0..<vertices.count {
            let j = (i + 1) % vertices.count
            area += vertices[i].x * vertices[j].y
            area -= vertices[j].x * vertices[i].y
        }
        return area * 0.5
    }

    /// Centroide de un polígono
    static func polygonCentroid(_ vertices: [SIMD2<Float>]) -> SIMD2<Float> {
        guard vertices.count >= 3 else { return vertices.first ?? .zero }
        var sum = SIMD2<Float>.zero
        for v in vertices { sum += v }
        return sum / Float(vertices.count)
    }

    /// ¿El punto `p` está dentro del polígono? (ray-casting par/impar).
    static func polygonContains(_ vertices: [SIMD2<Float>], _ p: SIMD2<Float>) -> Bool {
        guard vertices.count >= 3 else { return false }
        var inside = false
        var j = vertices.count - 1
        for i in 0..<vertices.count {
            let vi = vertices[i], vj = vertices[j]
            if (vi.y > p.y) != (vj.y > p.y) {
                let t = (p.y - vi.y) / (vj.y - vi.y)
                if p.x < vi.x + t * (vj.x - vi.x) { inside.toggle() }
            }
            j = i
        }
        return inside
    }

    /// Discretiza un círculo en segmentos de línea
    static func discretizeCircle(center: SIMD2<Float>, radius: Float,
                                  segments: Int = 32) -> [(SIMD2<Float>, SIMD2<Float>)] {
        var result: [(SIMD2<Float>, SIMD2<Float>)] = []
        for i in 0..<segments {
            let a = Float(i) / Float(segments) * 2 * .pi
            let b = Float(i + 1) / Float(segments) * 2 * .pi
            let pA = center + SIMD2<Float>(cos(a), sin(a)) * radius
            let pB = center + SIMD2<Float>(cos(b), sin(b)) * radius
            result.append((pA, pB))
        }
        return result
    }
}

// MARK: - Visualización de región tocable

/// Genera un overlay que muestra las regiones cerradas como superficies
/// sombreadas y tocables en el viewport.
struct SketchRegionOverlay {
    /// Color de relleno de región (ámbar translúcido — "toca aquí para extruir")
    var fillColor: SIMD4<Float> = SIMD4<Float>(1.0, 0.48, 0.27, 0.15)
    /// Color del borde de la región
    var strokeColor: SIMD4<Float> = SIMD4<Float>(1.0, 0.48, 0.27, 0.6)
    /// Ancho del borde en unidades de mundo
    var strokeWidth: Float = 0.006

    /// Genera meshes de relleno + borde para las regiones detectadas
    func generate(for regions: [SketchRegionDetector.ClosedRegion],
                  on plane: SketchController.WorkPlane) -> (fill: Mesh?, stroke: Mesh?) {
        let fill = SketchRegionDetector.fillMesh(for: regions, on: plane, color: fillColor)

        // Borde: tubos finos sobre el perímetro de cada región
        var strokeVerts: [Vertex] = []
        var strokeIdx: [UInt32] = []
        let offset = plane.normal * 0.002

        for region in regions where !region.isHole && region.vertices.count >= 3 {
            var pts3D: [SIMD3<Float>] = []
            for v in region.vertices {
                pts3D.append(plane.origin + plane.u * v.x + plane.v * v.y + offset)
            }
            // Cerrar el lazo
            if let first = pts3D.first { pts3D.append(first) }
            GizmoBuilder.appendTube(polyline: pts3D, radius: strokeWidth,
                                    to: &strokeVerts, indices: &strokeIdx)
        }

        let stroke = strokeVerts.isEmpty ? nil : Mesh(vertices: strokeVerts, indices: strokeIdx)
        return (fill, stroke)
    }
}
