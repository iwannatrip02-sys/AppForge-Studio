import Foundation
import Metal

enum CacheError: Error {
    case modelNotFound(URL)
    case diskWriteFailed(Error)
    case diskReadFailed(Error)
}

final class ModelCacheService {
    private let memoryCache: NSCache<NSURL, Model>
    private let device: MTLDevice
    private let diskCacheURL: URL
    private let fileManager: FileManager
    private let serialQueue: DispatchQueue

    var memoryLimitMB: Int {
        memoryCache.totalCostLimit / (1024 * 1024)
    }

    init(device: MTLDevice, maxMemoryMB: Int = 128) {
        self.device = device
        self.fileManager = .default
        self.serialQueue = DispatchQueue(label: "com.appforgestudio.modelcache.disk", qos: .utility)

        self.memoryCache = {
            let cache = NSCache<NSURL, Model>()
            cache.totalCostLimit = maxMemoryMB * 1024 * 1024
            cache.countLimit = 50
            return cache
        }()

        let cachesDir = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
        diskCacheURL = cachesDir.appendingPathComponent("com.appforgestudio.modelcache")
        try? fileManager.createDirectory(at: diskCacheURL, withIntermediateDirectories: true)
    }

    func cachedModel(for url: URL) -> Model? {
        if let cached = memoryCache.object(forKey: url as NSURL) {
            return cached
        }
        return loadFromDisk(for: url)?.0
    }

    func cache(_ model: Model, for url: URL) {
        let cost = estimateCost(for: model)
        memoryCache.setObject(model, forKey: url as NSURL, cost: cost)

        let diskPath = diskCachePath(for: url)
        serialQueue.async { [weak self] in
            self?.writeToDisk(model, sourceURL: url, at: diskPath)
        }
    }

    func removeModel(for url: URL) {
        memoryCache.removeObject(forKey: url as NSURL)
        let diskURL = diskCachePath(for: url)
        serialQueue.async { [weak self] in
            try? self?.fileManager.removeItem(at: diskURL)
        }
    }

    func clearCache() {
        memoryCache.removeAllObjects()
        serialQueue.async { [weak self] in
            guard let self else { return }
            try? self.fileManager.removeItem(at: self.diskCacheURL)
            try? self.fileManager.createDirectory(at: self.diskCacheURL, withIntermediateDirectories: true)
        }
    }

    func containsModel(for url: URL) -> Bool {
        memoryCache.object(forKey: url as NSURL) != nil
            || fileManager.fileExists(atPath: diskCachePath(for: url).path)
    }

    func diskCacheSize() -> Int64 {
        guard let enumerator = fileManager.enumerator(
            at: diskCacheURL,
            includingPropertiesForKeys: [.fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else { return 0 }

        var total: Int64 = 0
        for case let fileURL as URL in enumerator {
            guard let values = try? fileURL.resourceValues(forKeys: [.fileSizeKey]),
                  let size = values.fileSize else { continue }
            total += Int64(size)
        }
        return total
    }

    func restoreCachedModels() -> [Model] {
        guard let contents = try? fileManager.contentsOfDirectory(
            at: diskCacheURL,
            includingPropertiesForKeys: nil
        ) else { return [] }

        var restored: [Model] = []
        for url in contents {
            guard let (model, sourceURL) = loadFromDisk(at: url) else { continue }
            cache(model, for: sourceURL)
            restored.append(model)
        }
        return restored
    }

    // MARK: - Private

    private func diskCachePath(for url: URL) -> URL {
        let key = url.absoluteString.data(using: .utf8)!.base64EncodedString()
        return diskCacheURL.appendingPathComponent("\(key).cache")
    }

    private func estimateCost(for model: Model) -> Int {
        model.meshes.reduce(0) { acc, mesh in
            acc + mesh.vertices.count * MemoryLayout<Vertex>.stride
                + mesh.indices.count * MemoryLayout<UInt32>.stride
        }
    }

    private func writeToDisk(_ model: Model, sourceURL: URL, at diskURL: URL) {
        let codable = ModelCacheCodable(model: model, sourceURL: sourceURL.absoluteString)
        do {
            let data = try JSONEncoder().encode(codable)
            try data.write(to: diskURL, options: .atomic)
        } catch {
            print("[ModelCacheService] Disk write failed: \(error.localizedDescription)")
        }
    }

    private func loadFromDisk(for url: URL) -> (Model, URL)? {
        let diskURL = diskCachePath(for: url)
        return loadFromDisk(at: diskURL)
    }

    private func loadFromDisk(at diskURL: URL) -> (Model, URL)? {
        guard fileManager.fileExists(atPath: diskURL.path),
              let data = try? Data(contentsOf: diskURL),
              let codable = try? JSONDecoder().decode(ModelCacheCodable.self, from: data) else { return nil }
        return codable.restore(device: device)
    }
}

// MARK: - Codable disk representation

private struct VertexCacheCodable: Codable {
    let px, py, pz: Float
    let nx, ny, nz: Float
    let ux, uy: Float

    init(_ vertex: Vertex) {
        px = vertex.position.x; py = vertex.position.y; pz = vertex.position.z
        nx = vertex.normal.x;   ny = vertex.normal.y;   nz = vertex.normal.z
        ux = vertex.uv.x;       uy = vertex.uv.y
    }

    var vertex: Vertex {
        Vertex(position: SIMD3(px, py, pz), normal: SIMD3(nx, ny, nz), uv: SIMD2(ux, uy))
    }
}

private struct MeshCacheCodable: Codable {
    let vertices: [VertexCacheCodable]
    let indices: [UInt32]

    init(_ mesh: Mesh) {
        vertices = mesh.vertices.map(VertexCacheCodable.init)
        indices = mesh.indices
    }

    func restore(device: MTLDevice) -> Mesh {
        var mesh = Mesh(
            vertices: vertices.map { $0.vertex },
            indices: indices
        )
        mesh.uploadToGPU(device: device)
        return mesh
    }
}

private struct ModelCacheCodable: Codable {
    let id: UUID
    let name: String
    let sourceURL: String
    let meshes: [MeshCacheCodable]

    init(model: Model, sourceURL: String) {
        id = model.id
        name = model.name
        self.sourceURL = sourceURL
        meshes = model.meshes.map(MeshCacheCodable.init)
    }

    func restore(device: MTLDevice) -> (Model, URL)? {
        guard let source = URL(string: sourceURL) else { return nil }
        let model = Model(name: name)
        model.meshes = meshes.map { $0.restore(device: device) }
        return (model, source)
    }
}
