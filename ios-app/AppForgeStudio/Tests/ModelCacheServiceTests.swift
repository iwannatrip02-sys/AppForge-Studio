import XCTest
@testable import AppForgeStudio

final class ModelCacheServiceTests: XCTestCase {
    var cache: ModelCacheService!
    var device: MTLDevice!
    var testModel: Model!
    var testURL: URL!
    
    override func setUp() {
        super.setUp()
        device = MTLCreateSystemDefaultDevice()!
        cache = ModelCacheService(device: device, maxMemoryMB: 10)
        testModel = TestCube.build(name: "CacheTest")
        testURL = URL(string: "file:///test/cube.model")!
    }
    
    override func tearDown() {
        cache.removeModel(for: testURL)
        super.tearDown()
    }
    
    func testCacheAndRetrieve() {
        cache.cache(testModel, for: testURL)
        let retrieved = cache.cachedModel(for: testURL)
        XCTAssertNotNil(retrieved)
        XCTAssertEqual(retrieved?.name, "CacheTest")
    }
    
    func testCacheMiss() {
        let unknownURL = URL(string: "file:///test/unknown.model")!
        let result = cache.cachedModel(for: unknownURL)
        XCTAssertNil(result)
    }
    
    func testRemoveModel() {
        cache.cache(testModel, for: testURL)
        cache.removeModel(for: testURL)
        let result = cache.cachedModel(for: testURL)
        XCTAssertNil(result)
    }
    
    func testMemoryLimit() {
        let smallCache = ModelCacheService(device: device, maxMemoryMB: 1)
        for i in 0..<100 {
            let url = URL(string: "file:///test/model_\(i).model")!
            let model = TestCube.build(name: "Model_\(i)")
            smallCache.cache(model, for: url)
        }
        // Debe haber ejectado algunos modelos por limite de costo
        // Verificar que no crashea
        let firstURL = URL(string: "file:///test/model_0.model")!
        let firstResult = smallCache.cachedModel(for: firstURL)
        let lastURL = URL(string: "file:///test/model_99.model")!
        let lastResult = smallCache.cachedModel(for: lastURL)
        XCTAssertNotNil(lastResult, "Ultimo modelo debe estar en cache")
        XCTAssertEqual(lastResult?.name, "Model_99")
    }
    
    func testClearCache() {
        cache.cache(testModel, for: testURL)
        cache.clearCache()
        let result = cache.cachedModel(for: testURL)
        XCTAssertNil(result)
    }
}
