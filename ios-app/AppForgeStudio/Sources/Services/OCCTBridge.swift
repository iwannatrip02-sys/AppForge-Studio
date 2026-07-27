import Foundation
import simd
import OCCTSwift

/// Bridges OCCTSwift B-rep shapes (from gsdali/OCCTSwift) to AppForge Studio's Mesh type for Metal rendering.
/// All OCCTSwift operations return Shape? — operations can fail on degenerate geometry.
enum OCCTBridge {
    
    /// Triangulate an OCCTSwift B-rep shape into our Mesh type.
    /// OCCTSwift.mesh() returns [SIMD3<Float>] vertices, [SIMD3<Float>] normals, [UInt32] indices.
    /// Los DEFAULTS son los de `.medium`, no los de OCCT: el default angular de
    /// OCCT (0.5 rad ≈ 28.6°) deja las curvas facetadas, y cualquier llamador
    /// que omitiera el parámetro heredaba ese defecto en silencio (le pasó a
    /// `BooleanEngine`). Prefiere `toMesh(_:quality:)` para elegir calidad.
    static func shapeToMesh(_ shape: OCCTSwift.Shape,
                            linearDeflection: Double = 0.1,
                            angularDeflection: Double = 0.20) -> Mesh? {
        guard let occtMesh = shape.mesh(linearDeflection: linearDeflection,
                                         angularDeflection: angularDeflection) else {
            return nil
        }

        // CRÍTICO (crash device 2026-07-16, watchdog 0x8BADF00D al abrir
        // proyecto): las propiedades del mesh de OCCTSwift pueden ser COMPUTADAS
        // (convierten los buffers C++ en cada acceso). Accederlas dentro del
        // bucle (`occtMesh.vertices[i]`) convertía la copia en O(n²) y congelaba
        // el main thread hasta que iOS mataba la app. Se materializan UNA vez.
        let positions = occtMesh.vertices
        let occtNormals = occtMesh.normals
        let indices = occtMesh.indices
        let vertexCount = positions.count
        let normalCount = occtNormals.count

        // El bridge nativo de OCCTSwift rellena (0,0,1) cuando la triangulación
        // no trae normales → TODAS las normales iguales → sombreado plano (los
        // objetos se ven como siluetas grises, feedback de device). Detectar
        // normales ausentes O degeneradas y calcularlas desde los triángulos.
        let degenerate: Bool = {
            guard normalCount >= vertexCount, let first = occtNormals.first else { return true }
            return !occtNormals.contains { simd_distance($0, first) > 0.01 }
        }()
        let normals: [SIMD3<Float>] = degenerate
            ? Self.computeVertexNormals(positions: positions, indices: indices)
            : occtNormals

        var vertices: [Vertex] = []
        vertices.reserveCapacity(vertexCount)
        for i in 0..<vertexCount {
            vertices.append(Vertex(position: positions[i],
                                   normal: i < normals.count ? normals[i] : SIMD3<Float>(0, 1, 0),
                                   uv: .zero))
        }

        return Mesh(vertices: vertices, indices: indices)
    }

    /// Normales por vértice área-ponderadas (acumulación del cross por triángulo).
    /// OCCT triangula por cara sin compartir vértices entre caras → las aristas
    /// vivas se conservan nítidas.
    static func computeVertexNormals(positions: [SIMD3<Float>],
                                     indices: [UInt32]) -> [SIMD3<Float>] {
        var acc = [SIMD3<Float>](repeating: .zero, count: positions.count)
        var i = 0
        while i + 2 < indices.count {
            let a = Int(indices[i]), b = Int(indices[i + 1]), c = Int(indices[i + 2])
            i += 3
            guard a < positions.count, b < positions.count, c < positions.count else { continue }
            let n = simd_cross(positions[b] - positions[a], positions[c] - positions[a])
            acc[a] += n; acc[b] += n; acc[c] += n
        }
        return acc.map { simd_length($0) > 1e-9 ? simd_normalize($0) : SIMD3<Float>(0, 1, 0) }
    }
    
    static func toMesh(_ shape: OCCTSwift.Shape, quality: MeshQuality = .medium) -> Mesh? {
        // Deflección LINEAL (desviación de cuerda máx, unidades de mundo) Y ANGULAR
        // (ángulo máx entre triángulos vecinos, radianes). La angular es la que
        // gobierna cuántos segmentos tiene una CURVA: OCCT por defecto usa 0.5 rad
        // (~28.6°) → un cilindro sale con ~13 gajos planos (el "juego indie" del
        // feedback en device). Bajarla hace las superficies curvas continuas.
        // Coste de memoria acotado: el nº de triángulos crece ~1/angular, y aun en
        // .medium (0.20 rad ≈ 11.5°, ~32 segmentos/círculo) es barato para un iPad.
        let linear: Double
        let angular: Double
        switch quality {
        case .low:     linear = 0.5;   angular = 0.5    // preview rápido
        case .medium:  linear = 0.1;   angular = 0.20   // display interactivo (curva continua)
        case .high:    linear = 0.02;  angular = 0.10
        case .ultra:   linear = 0.005; angular = 0.05
        }
        return shapeToMesh(shape, linearDeflection: linear, angularDeflection: angular)
    }
    
    /// Require mesh (fatal on nil) for cases where we know the shape is valid.
    static func toMeshRequired(_ shape: OCCTSwift.Shape, quality: MeshQuality = .medium) -> Mesh {
        toMesh(shape, quality: quality) ?? Mesh(vertices: [], indices: [])
    }

    /// Malla de ARISTAS del B-rep como LÍNEAS nítidas (no tubos 3D): el look Shapr3D
    /// — todo sólido exacto muestra sus bordes como líneas planas anti-aliased. El
    /// renderer las dibuja con el pipeline de línea (núcleo acero oscuro + halo claro
    /// de contraste), constante en píxeles y opaco también en rayos X. nil si el
    /// shape no tiene aristas (esfera).
    ///
    /// El parámetro `radius` se mantiene por compatibilidad de firma con las llamadas
    /// existentes (`LivePreviewEngine` usa 0.005) pero YA NO define geometría de tubo:
    /// el grosor real es en píxeles y lo fija el shader (`LineUniforms.halfWidthPx`).
    static func edgesMesh(_ shape: OCCTSwift.Shape, radius: Float = 0.008) -> Mesh? {
        var vertices: [Vertex] = []
        var indices: [UInt32] = []
        for edge in shape.edges() {
            let pts = edge.points(count: edgeSampleCount(edge))
                .map { SIMD3<Float>(Float($0.x), Float($0.y), Float($0.z)) }
            LineRibbonBuilder.appendPolyline(pts, to: &vertices, indices: &indices)
        }
        return vertices.isEmpty ? nil : Mesh(vertices: vertices, indices: indices)
    }

    /// Nº de muestras de una arista para que la POLILÍNEA no se separe de la
    /// curva real más de `maxDeviation`.
    ///
    /// Antes era `edge.isLine ? 2 : 24` — 24 puntos FIJOS para cualquier curva,
    /// sin mirar su radio. Con eso, la circunferencia de un cilindro se dibujaba
    /// como un polígono de 24 lados: aunque la superficie sea un cilindro
    /// exacto, la SILUETA se veía facetada, que es lo que define visualmente la
    /// forma. Arreglar el teselado de la malla sin arreglar el de las aristas
    /// deja el defecto a la vista (feedback de device: "el cilindro sigue
    /// creando un montón de caras").
    ///
    /// La flecha (sagitta) de una cuerda que abarca un ángulo θ en un círculo de
    /// radio r es `r(1 − cos(θ/2))`; despejando θ sale el paso angular máximo, y
    /// el nº de tramos es el barrido dividido por ese paso. Así una pieza grande
    /// recibe más muestras que una pequeña, en vez de las mismas 24.
    static func edgeSampleCount(_ edge: OCCTSwift.Edge,
                                maxDeviation: Double = 0.004) -> Int {
        if edge.isLine { return 2 }
        let length = edge.length
        guard length > 1e-9, maxDeviation > 0 else { return 24 }

        // Radio de curvatura en el punto MEDIO del rango paramétrico: exacto
        // para círculos y arcos; aproximación razonable para splines.
        guard let bounds = edge.parameterBounds else { return 24 }
        let mid = (bounds.first + bounds.last) / 2
        guard let k = edge.curvature(at: mid), k > 1e-12 else { return 24 }

        let r = 1 / k
        let ratio = max(0, 1 - maxDeviation / r)
        let maxStep = 2 * acos(min(1, ratio))          // radianes por tramo
        guard maxStep > 1e-9 else { return 512 }

        let sweep = length / r                          // ángulo total del arco
        let segments = Int(ceil(sweep / maxStep))
        // Piso 24 para no empeorar nunca lo que ya había; techo para acotar la
        // memoria de la cinta de línea en piezas enormes.
        return max(24, min(512, segments + 1))
    }
}

enum MeshQuality: String, CaseIterable {
    case low, medium, high, ultra
}

// MARK: - OCCTSwift.Shape convenience extensions for AppForge

extension OCCTSwift.Shape {
    
    /// Fallback mesh with default quality
    func appforgeMesh(quality: MeshQuality = .medium) -> Mesh {
        OCCTBridge.toMesh(self, quality: quality) ?? Mesh(vertices: [], indices: [])
    }
    
    /// Safe union that handles optional result
    func safeUnion(_ other: OCCTSwift.Shape) -> OCCTSwift.Shape {
        (self + other) ?? self
    }
    
    /// Safe subtract that handles optional result
    func safeSubtract(_ other: OCCTSwift.Shape) -> OCCTSwift.Shape {
        (self - other) ?? self
    }
    
    /// Safe intersect that handles optional result
    func safeIntersect(_ other: OCCTSwift.Shape) -> OCCTSwift.Shape {
        (self & other) ?? self
    }
    
    /// Safe fillet
    func safeFillet(radius: Double) -> OCCTSwift.Shape {
        filleted(radius: radius) ?? self
    }
    
    /// Safe chamfer
    func safeChamfer(distance: Double) -> OCCTSwift.Shape {
        chamfered(distance: distance) ?? self
    }
    
    /// Safe shell (negative = inward)
    func safeShell(thickness: Double) -> OCCTSwift.Shape {
        shelled(thickness: thickness) ?? self
    }
}
