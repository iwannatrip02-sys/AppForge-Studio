import Combine
import Satin
import Foundation
import Metal
import simd
import OSLog

private let logger = Logger(subsystem: "com.appforgestudio", category: "Model3D")
class Model: ObservableObject {
    let id: UUID
    @Published var name: String
    @Published var vertexBuffer: MTLBuffer?
    @Published var indexBuffer: MTLBuffer?
    @Published var vertexCount: Int
    @Published var indexCount: Int
    @Published var meshes: [Mesh] = []
    /// B-rep vivo (OCCT) — fuente de verdad geométrica cuando existe.
    /// Las operaciones de ingeniería (booleanos/fillet/push-pull) van vía BRepModeling.
    var cadShape: CADShape?
    /// Se incrementa cuando la GEOMETRÍA de la malla cambia (features, bakes,
    /// subdivisión). El renderer lo usa para reconstruir buffers GPU.
    /// Cada modelo NUEVO nace con una versión única (nonce): reemplazar un
    /// overlay por otro (mismo conteo) también cambia la firma de la escena —
    /// antes el swap dejaba visuales CONGELADOS hasta el siguiente rebuild
    /// ("no se ve hasta que cambio de herramienta", feedback device).
    var geometryVersion: Int = Model.nextFreshVersion()

    private static var freshCounter = 0
    static func nextFreshVersion() -> Int {
        freshCounter += 1
        return freshCounter
    }

    /// Visibilidad en escena (ojo del panel de Elementos). Los invisibles no se
    /// dibujan NI se tocan.
    @Published var isVisible: Bool = true
    /// Aristas del B-rep como malla (tubos finos, look Shapr3D). La rellena
    /// OCCTBridge.edgesMesh en cada applyFeature/creación; el renderer la dibuja
    /// oscura y opaca (también en rayos X).
    var edgesMesh: Mesh?
    /// Puntos de vértice del B-rep SIEMPRE visibles (la "lógica del modelo":
    /// las esquinas son entidades reales y se ven — feedback device 2026-07-11).
    /// Cacheado por geometryVersion; se recalcula solo cuando la geometría cambia.
    private var vertexDotsCache: Mesh?
    private var vertexDotsCacheVersion: Int = -1
    func vertexDotsMesh() -> Mesh? {
        if vertexDotsCacheVersion == geometryVersion { return vertexDotsCache }
        vertexDotsCacheVersion = geometryVersion
        guard let shape = cadShape else { vertexDotsCache = nil; return nil }
        let verts = BRepVertexPicker.vertices(of: shape)
        // Tope de seguridad: un sólido orgánico con cientos de esquinas no
        // necesita puntos (y los octaedros saturarían el draw).
        guard !verts.isEmpty, verts.count <= 512 else { vertexDotsCache = nil; return nil }
        var v: [Vertex] = []
        var i: [UInt32] = []
        for p in verts {
            let dot = BRepVertexPicker.highlightDot(at: p, size: 0.02)
            let base = UInt32(v.count)
            v.append(contentsOf: dot.vertices)
            i.append(contentsOf: dot.indices.map { $0 + base })
        }
        vertexDotsCache = Mesh(vertices: v, indices: i)
        return vertexDotsCache
    }
    @Published var color: SIMD4<Float>
    @Published var cadHistoryID: UUID?
    @Published var originOp: String?
    @Published var usesPBR: Bool = false
    @Published var pbrMaterial: PBRMaterial = PBRMaterial()

    @Published var position: SIMD3<Float>
    @Published var rotation: simd_quatf
    @Published var scale: SIMD3<Float>

    var transform: simd_float4x4 {
        get {
            let T = simd_float4x4(
                SIMD4<Float>(1, 0, 0, 0),
                SIMD4<Float>(0, 1, 0, 0),
                SIMD4<Float>(0, 0, 1, 0),
                SIMD4<Float>(position.x, position.y, position.z, 1)
            )
            let R = simd_float4x4(rotation)
            let S = simd_float4x4(
                SIMD4<Float>(scale.x, 0, 0, 0),
                SIMD4<Float>(0, scale.y, 0, 0),
                SIMD4<Float>(0, 0, scale.z, 0),
                SIMD4<Float>(0, 0, 0, 1)
            )
            return T * R * S
        }
        set {
            updateTransform(newValue)
        }
    }

    init(name: String = "Model", vertices: [Float] = [], indices: [UInt16] = [], device: MTLDevice? = nil) {
        self.id = UUID()
        self.name = name
        self.vertexCount = vertices.count / 13
        self.indexCount = indices.count
        self.position = .zero
        self.rotation = simd_quatf(real: 1, imag: .zero)
        self.scale = SIMD3<Float>(1, 1, 1)
        // Gris claro cálido estilo Shapr3D (con el shading estudio se lee premium;
        // el 0.7 anterior renderizaba oscuro y "de los 90")
        self.color = SIMD4<Float>(0.80, 0.81, 0.84, 1.0)

        if let device = device, !vertices.isEmpty {
            setBuffers(vertices: vertices, indices: indices, device: device)
        }
    }

    func setBuffers(vertices: [Float], indices: [UInt16], device: MTLDevice) {
        vertexBuffer = device.makeBuffer(bytes: vertices, length: vertices.count * MemoryLayout<Float>.stride, options: .storageModeShared)
        indexBuffer = device.makeBuffer(bytes: indices, length: indices.count * MemoryLayout<UInt16>.stride, options: .storageModeShared)
        vertexCount = vertices.count / 13
        indexCount = indices.count
    }

    func updateTransform(_ newTransform: simd_float4x4) {
        position = SIMD3<Float>(newTransform.columns.3.x, newTransform.columns.3.y, newTransform.columns.3.z)
        let sx = simd_length(SIMD3<Float>(newTransform.columns.0.x, newTransform.columns.0.y, newTransform.columns.0.z))
        let sy = simd_length(SIMD3<Float>(newTransform.columns.1.x, newTransform.columns.1.y, newTransform.columns.1.z))
        let sz = simd_length(SIMD3<Float>(newTransform.columns.2.x, newTransform.columns.2.y, newTransform.columns.2.z))
        scale = SIMD3<Float>(sx, sy, sz)
        let rotMatrix = simd_float3x3(
            SIMD3<Float>(newTransform.columns.0.x / sx, newTransform.columns.0.y / sy, newTransform.columns.0.z / sz),
            SIMD3<Float>(newTransform.columns.1.x / sx, newTransform.columns.1.y / sy, newTransform.columns.1.z / sz),
            SIMD3<Float>(newTransform.columns.2.x / sx, newTransform.columns.2.y / sy, newTransform.columns.2.z / sz)
        )
        rotation = simd_quatf(rotMatrix)
    }
}
