import XCTest
import simd
@testable import AppForgeStudio

/// Contrato de DETERMINISMO de la topología dinámica: el mismo trazo sobre la
/// misma malla produce SIEMPRE la misma malla.
///
/// `splitLongEdges` y `collapseShortEdges` iteraban `edges.keys` —un diccionario
/// sin orden garantizado— MUTANDO la malla dentro del bucle: cada corte añade
/// vértices y reescribe índices, y cada colapso los invalida. Con la mutación en
/// marcha el orden no es un detalle: cambia la topología resultante.
///
/// Sin esto, el guardado y el undo/redo dejan de ser reproducibles — dos
/// ejecuciones del mismo gesto divergen.
@MainActor
final class DynamicTopologyDeterminismTests: XCTestCase {

    /// Rejilla triangulada suficientemente densa para que haya aristas largas
    /// que partir dentro del radio del pincel.
    private func gridMesh(side: Int = 6, spacing: Float = 1.0) -> Mesh {
        var vertices: [Vertex] = []
        var indices: [UInt32] = []
        for r in 0...side {
            for c in 0...side {
                vertices.append(Vertex(position: SIMD3<Float>(Float(c) * spacing,
                                                             0,
                                                             Float(r) * spacing),
                                       normal: SIMD3<Float>(0, 1, 0)))
            }
        }
        let stride = side + 1
        for r in 0..<side {
            for c in 0..<side {
                let i0 = UInt32(r * stride + c)
                let i1 = UInt32(r * stride + c + 1)
                let i2 = UInt32((r + 1) * stride + c)
                let i3 = UInt32((r + 1) * stride + c + 1)
                indices.append(contentsOf: [i0, i1, i2])
                indices.append(contentsOf: [i1, i3, i2])
            }
        }
        return Mesh(vertices: vertices, indices: indices)
    }

    /// Huella reproducible de la malla: conteos + posiciones redondeadas, en
    /// orden. Si la topología diverge, la huella cambia.
    private func fingerprint(_ mesh: Mesh) -> String {
        var s = "v\(mesh.vertices.count)i\(mesh.indices.count)|"
        for v in mesh.vertices {
            s += String(format: "%.4f,%.4f,%.4f;", v.position.x, v.position.y, v.position.z)
        }
        for i in mesh.indices { s += "\(i)," }
        return s
    }

    func testSameStrokeProducesSameTopologyEveryRun() {
        let center = SIMD3<Float>(3, 0, 3)
        let radius: Float = 2.5

        var fingerprints = Set<String>()
        for _ in 0..<10 {
            let engine = DynamicTopologyEngine()
            var mesh = gridMesh()
            _ = engine.apply(to: &mesh, at: center, radius: radius)
            fingerprints.insert(fingerprint(mesh))
        }

        XCTAssertEqual(fingerprints.count, 1,
                       "el mismo trazo debe dar la MISMA malla; salieron \(fingerprints.count) distintas")
    }

    /// Y sigue haciendo su trabajo: la malla cambia de verdad (el test anterior
    /// pasaría trivialmente si la operación no hiciera nada).
    func testStrokeActuallyRefinesTheMesh() {
        let engine = DynamicTopologyEngine()
        var mesh = gridMesh()
        let before = mesh.vertices.count
        _ = engine.apply(to: &mesh, at: SIMD3<Float>(3, 0, 3), radius: 2.5)
        XCTAssertNotEqual(mesh.vertices.count, before,
                          "el remallado debe alterar la malla, si no el test de determinismo es vacío")
    }
}
