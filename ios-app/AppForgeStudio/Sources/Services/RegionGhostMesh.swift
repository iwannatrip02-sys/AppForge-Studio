import Foundation
import simd

/// Malla FANTASMA de la extrusión de una región, generada en Swift PURO (sin
/// OCCT) para el preview VIVO bajo el dedo. Se regenera CADA FRAME del drag —
/// es barato (unos pocos triángulos) y sigue el dedo a 60fps de forma
/// perfectamente continua, sin la discontinuidad de reconstruir el B-rep OCCT
/// por frame (queja #2 en device: "no se ve la extrusión en tiempo real, pasa
/// de un estado a otro").
///
/// El B-rep REAL (`extrudedShapeForActiveRegion` / `extrudeRegion`) se
/// construye SOLO al soltar. Este fantasma es un prisma CERRADO: tapa superior
/// (abanico desde el centroide), paredes laterales (dos triángulos por
/// segmento) y tapa inferior (abanico), para que se lea como sólido y para que
/// el cálculo de volumen por malla cerrada sea válido.
///
/// Entradas en coords 2D del PLANO de trabajo (`SketchController.WorkPlane`):
/// un punto 2D `p` mapea a mundo como `origin + u·p.x + v·p.y + normal·h`.
enum RegionGhostMesh {

    /// Construye la malla cerrada del prisma de altura `height` sobre `polygon`.
    /// - Parameters:
    ///   - polygon: vértices de la región en coords del plano (≥3, en orden).
    ///   - origin/u/v/normal: base del plano de trabajo.
    ///   - height: altura de extrusión (unidades de mundo).
    /// - Returns: vértices/índices de un prisma cerrado, o `nil` si degenerado.
    static func build(polygon: [SIMD2<Float>],
                      origin: SIMD3<Float>, u: SIMD3<Float>,
                      v: SIMD3<Float>, normal: SIMD3<Float>,
                      height: Float) -> Mesh? {
        guard polygon.count >= 3, height > 1e-5 else { return nil }

        func world(_ p: SIMD2<Float>, _ h: Float) -> SIMD3<Float> {
            origin + u * p.x + v * p.y + normal * h
        }

        let centroid = polygon.reduce(SIMD2<Float>(0, 0), +) / Float(polygon.count)

        var vertices: [Vertex] = []
        var indices: [UInt32] = []
        func add(_ p: SIMD3<Float>, _ n: SIMD3<Float>) -> UInt32 {
            vertices.append(Vertex(position: p, normal: n, uv: .zero))
            return UInt32(vertices.count - 1)
        }

        let up = simd_normalize(normal)
        let down = -up

        // Tapa SUPERIOR: abanico desde el centroide (normal hacia +normal).
        let topCenter = add(world(centroid, height), up)
        // Tapa INFERIOR: abanico desde el centroide (normal hacia −normal).
        let botCenter = add(world(centroid, 0), down)

        let n = polygon.count
        for i in 0..<n {
            let a = polygon[i]
            let b = polygon[(i + 1) % n]

            // Triángulo de la tapa superior (centro → a → b).
            let ta = add(world(a, height), up)
            let tb = add(world(b, height), up)
            indices.append(contentsOf: [topCenter, ta, tb])

            // Triángulo de la tapa inferior (centro → b → a: winding opuesto).
            let ba = add(world(a, 0), down)
            let bb = add(world(b, 0), down)
            indices.append(contentsOf: [botCenter, bb, ba])

            // Pared del segmento a→b: quad (2 triángulos), normal saliente.
            let edge = world(b, 0) - world(a, 0)
            var wall = simd_cross(edge, up)
            let wallLen = simd_length(wall)
            wall = wallLen > 1e-6 ? wall / wallLen : up
            let w0 = add(world(a, 0), wall)
            let w1 = add(world(b, 0), wall)
            let w2 = add(world(a, height), wall)
            let w3 = add(world(b, height), wall)
            indices.append(contentsOf: [w0, w1, w2, w1, w3, w2])
        }

        return Mesh(vertices: vertices, indices: indices)
    }

    /// Volumen encerrado por la malla (teorema de la divergencia sobre los
    /// triángulos): sirve al test para verificar que el prisma tiene el volumen
    /// esperado. Robusto al winding (devuelve el valor absoluto).
    static func enclosedVolume(_ mesh: Mesh) -> Float {
        var sixVol: Float = 0
        var i = 0
        while i + 2 < mesh.indices.count {
            let a = mesh.vertices[Int(mesh.indices[i])].position
            let b = mesh.vertices[Int(mesh.indices[i + 1])].position
            let c = mesh.vertices[Int(mesh.indices[i + 2])].position
            sixVol += simd_dot(a, simd_cross(b, c))
            i += 3
        }
        return abs(sixVol) / 6
    }
}
