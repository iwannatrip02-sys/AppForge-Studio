import Foundation
import simd
import OCCTSwift
import SketchKernel

/// Construye el perfil B-rep de una región del sketch CONSERVANDO la geometría
/// analítica de sus curvas.
///
/// ## Por qué existe
///
/// `RegionFinder` arma un grafo planar sobre segmentos DISCRETIZADOS, así que el
/// contorno de una región sale como polígono. Cuando ese polígono alimentaba
/// directamente la extrusión, un círculo dibujado producía un **prisma de ~50
/// caras planas** en vez de un cilindro. Eso explica tres síntomas reportados
/// desde el iPad que parecían cosméticos y no lo eran:
///
/// - "un cilindro no se ve redondo": es que geométricamente NO era redondo.
/// - "los objetos se separan por polígonos": el overlay de aristas dibujaba las
///   ~50 aristas vivas REALES del prisma.
/// - "no se pueden construir cosas complejas": un fillet sobre eso son 50
///   fillets, el STEP exportado no tiene cilindros, y el reconocimiento de
///   agujeros (que busca caras cilíndricas) nunca podía encontrar nada.
///
/// Con la procedencia que ahora viaja por el grafo (`RegionEdge`: curva +
/// intervalo de parámetro), aquí se reconstruye cada tramo con su curva OCCT
/// nativa. Un círculo vuelve a ser `Wire.circle` → la extrusión es un cilindro
/// real de 3 caras.
///
/// ## Degradación honesta
///
/// Devuelve `nil` si algún tramo no se puede reconstruir. El llamador cae
/// entonces al perfil poligonal de siempre — ganar cilindros nunca puede costar
/// una extrusión que antes funcionaba.
enum AnalyticProfileBuilder {

    /// Wire cerrado en coordenadas de MUNDO, con curvas analíticas.
    ///
    /// - Parameters:
    ///   - boundary: contorno con procedencia (`SketchRegion.boundary`).
    ///   - model: el sketch donde viven las curvas referenciadas.
    ///   - origin/uAxis/vAxis: el plano de trabajo (ejes unitarios: la métrica
    ///     del sketch se conserva, así que un radio 2D es un radio 3D).
    ///   - normal: normal del plano — define el plano de círculos y arcos.
    static func wire(boundary: [SketchKernel.RegionEdge],
                     in model: SketchModel,
                     origin: SIMD3<Double>,
                     uAxis: SIMD3<Double>,
                     vAxis: SIMD3<Double>,
                     normal: SIMD3<Double>) -> Wire? {
        guard !boundary.isEmpty else { return nil }

        func world3(_ p: Vec2) -> SIMD3<Double> {
            origin + uAxis * p.x + vAxis * p.y
        }

        var pieces: [Wire] = []
        pieces.reserveCapacity(boundary.count)
        for edge in boundary {
            guard let curve = model.curves[edge.curveID],
                  let geometry = CurveGeometry.resolve(curve, in: model),
                  let piece = wire(for: edge, geometry: geometry,
                                   world3: world3, normal: normal)
            else { return nil }
            pieces.append(piece)
        }

        // Un solo tramo cerrado (círculo suelto) ya ES el contorno.
        if pieces.count == 1 { return pieces[0] }
        return Wire.join(pieces)
    }

    // MARK: - Un tramo

    private static func wire(for edge: SketchKernel.RegionEdge,
                             geometry: CurveGeometry,
                             world3: (Vec2) -> SIMD3<Double>,
                             normal: SIMD3<Double>) -> Wire? {
        // El tramo cubre la curva ENTERA (círculo cerrado recorrido completo).
        let isFullSweep = abs(edge.sweep - 1) < 1e-6

        switch geometry.shape {
        case .line:
            return Wire.line(from: world3(geometry.evaluate(edge.tStart)),
                             to: world3(geometry.evaluate(edge.tEnd)))

        case .circle(let center, let radius):
            if isFullSweep {
                return Wire.circle(origin: world3(center), normal: normal, radius: radius)
            }
            return arcWire(geometry: geometry, edge: edge, world3: world3)

        case .arc(let center, let radius, _, _, _):
            // Un arco de barrido completo es el círculo del que sale.
            if isFullSweep, geometry.evaluate(0).distance(to: geometry.evaluate(1)) < 1e-9 {
                return Wire.circle(origin: world3(center), normal: normal, radius: radius)
            }
            return arcWire(geometry: geometry, edge: edge, world3: world3)

        case .sampledSpline:
            // BSpline REAL interpolada por los puntos del tramo — no una
            // polilínea. Sigue siendo una aproximación de la Catmull-Rom del
            // kernel, pero es una curva suave para OCCT (fillets y offsets
            // se comportan) en vez de N aristas rectas.
            var points: [SIMD3<Double>] = []
            let samples = 24
            points.reserveCapacity(samples + 1)
            for k in 0...samples {
                let t = edge.tStart + (edge.tEnd - edge.tStart) * Double(k) / Double(samples)
                points.append(world3(geometry.evaluate(t)))
            }
            return Wire.interpolate(through: points)
        }
    }

    /// Arco por TRES puntos (inicio, medio, fin).
    ///
    /// Se prefiere al constructor por ángulos (`arc(center:radius:startAngle:...)`)
    /// porque este no depende de la dirección X del plano: cuando el sketch vive
    /// en una cara arbitraria de un sólido, el eje X del plano de trabajo no es
    /// un eje canónico del mundo y el constructor angular queda ambiguo.
    private static func arcWire(geometry: CurveGeometry,
                                edge: SketchKernel.RegionEdge,
                                world3: (Vec2) -> SIMD3<Double>) -> Wire? {
        let midT = (edge.tStart + edge.tEnd) / 2
        let start = world3(geometry.evaluate(edge.tStart))
        let mid = world3(geometry.evaluate(midT))
        let end = world3(geometry.evaluate(edge.tEnd))
        // Degenerado (extremos y medio colineales por un barrido diminuto):
        // una recta es la respuesta correcta y OCCT no traga el arco.
        if simd_length(simd_cross(mid - start, end - start)) < 1e-12 {
            return Wire.line(from: start, to: end)
        }
        return Wire.arc(start: start, midpoint: mid, end: end)
    }
}
