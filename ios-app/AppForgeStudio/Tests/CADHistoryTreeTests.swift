import XCTest
@testable import AppForgeStudio

/// Tests para el árbol de features paramétrico (Oleada 1).
/// Verifica: grabación, undo/redo, edición de parámetros, suppress,
/// invalidación downstream, y rebuildSceneFromOperations.
@MainActor
final class CADHistoryTreeTests: XCTestCase {

    var tree: CADHistoryTree!

    override func setUp() {
        super.setUp()
        tree = CADHistoryTree()
    }

    override func tearDown() {
        tree.clear()
        tree = nil
        super.tearDown()
    }

    // MARK: - Record

    func testRecordSingleOperation() {
        let op = CADOperation(type: .createPrimitive, description: "Box 1.0mm",
                              parameters: ["size": 1.0])
        let node = tree.recordOperation(op)
        XCTAssertEqual(tree.operationCount, 1)
        XCTAssertEqual(tree.activeChain.count, 1)
        XCTAssertEqual(node.operation.type, .createPrimitive)
        XCTAssertEqual(node.operation.parameters["size"], 1.0)
        XCTAssertTrue(tree.isDirty)
        XCTAssertEqual(tree.lastOperationDescription, "Box 1.0mm")
    }

    func testRecordMultipleOperationsBuildsChain() {
        tree.recordOperation(CADOperation(type: .createPrimitive, description: "Box"))
        tree.recordOperation(CADOperation(type: .extrude, description: "Extrude face",
                                          parameters: ["distance": 2.0]))
        tree.recordOperation(CADOperation(type: .fillet, description: "Fillet edge",
                                          parameters: ["radius": 0.5]))
        XCTAssertEqual(tree.operationCount, 3)
        XCTAssertEqual(tree.activeChain.count, 3)
        // La cadena es lineal: Box → Extrude → Fillet
        XCTAssertEqual(tree.activeChain[0].type, .createPrimitive)
        XCTAssertEqual(tree.activeChain[1].type, .extrude)
        XCTAssertEqual(tree.activeChain[2].type, .fillet)
    }

    // MARK: - Undo / Redo

    func testUndoRedo() {
        tree.recordOperation(CADOperation(type: .createPrimitive, description: "A"))
        tree.recordOperation(CADOperation(type: .extrude, description: "B"))
        XCTAssertEqual(tree.operationCount, 2)

        let undone = tree.undo()
        XCTAssertEqual(undone?.description, "B")
        XCTAssertEqual(tree.activeChain.count, 1)
        XCTAssertTrue(tree.canRedo)

        let redone = tree.redo()
        XCTAssertEqual(redone?.description, "B")
        XCTAssertEqual(tree.activeChain.count, 2)
        XCTAssertTrue(tree.canUndo)
    }

    func testUndoEmptyReturnsNil() {
        XCTAssertNil(tree.undo())
        XCTAssertFalse(tree.canUndo)
    }

    func testRedoEmptyReturnsNil() {
        XCTAssertNil(tree.redo())
        XCTAssertFalse(tree.canRedo)
    }

    func testRedoStackClearedOnNewOperation() {
        tree.recordOperation(CADOperation(type: .createPrimitive, description: "A"))
        tree.recordOperation(CADOperation(type: .extrude, description: "B"))
        _ = tree.undo()
        XCTAssertTrue(tree.canRedo)
        // Nueva operación → redo stack se limpia
        tree.recordOperation(CADOperation(type: .fillet, description: "C"))
        XCTAssertFalse(tree.canRedo)
        XCTAssertEqual(tree.activeChain.count, 2) // A → C (B fue reemplazado)
    }

    // MARK: - Parameter editing

    func testUpdateParameterEmitsRecomputeRequested() {
        let node = tree.recordOperation(
            CADOperation(type: .extrude, description: "Extrude",
                        parameters: ["distance": 1.0]))
        XCTAssertNil(tree.recomputeRequested)

        tree.updateParameter(nodeID: node.id, key: "distance", value: 3.0)
        XCTAssertNotNil(tree.recomputeRequested)
        XCTAssertEqual(tree.recomputeRequested?.fromNodeID, node.id)
        XCTAssertEqual(tree.recomputeRequested?.changedParameter, "distance")
        XCTAssertEqual(tree.findNode(with: node.id)?.operation.parameters["distance"], 3.0)
    }

    func testUpdateParameterInvalidatesDownstreamSnapshots() {
        let n1 = tree.recordOperation(CADOperation(type: .createPrimitive, description: "Box"),
                                       brepSnapshot: Data([0x01]))
        let n2 = tree.recordOperation(CADOperation(type: .extrude, description: "Extrude"),
                                       brepSnapshot: Data([0x02]))
        let n3 = tree.recordOperation(CADOperation(type: .fillet, description: "Fillet"),
                                       brepSnapshot: Data([0x03]))

        // Editar el primer nodo invalida snapshots de n1, n2, n3
        tree.updateParameter(nodeID: n1.id, key: "size", value: 5.0)
        XCTAssertNil(tree.findNode(with: n1.id)?.brepSnapshot)
        XCTAssertNil(tree.findNode(with: n2.id)?.brepSnapshot)
        XCTAssertNil(tree.findNode(with: n3.id)?.brepSnapshot)
    }

    // MARK: - Suppress

    func testToggleSuppress() {
        let node = tree.recordOperation(CADOperation(type: .fillet, description: "Fillet"))
        XCTAssertFalse(node.isSuppressed)

        tree.toggleSuppress(nodeID: node.id)
        XCTAssertTrue(tree.findNode(with: node.id)?.isSuppressed ?? false)

        tree.toggleSuppress(nodeID: node.id)
        XCTAssertFalse(tree.findNode(with: node.id)?.isSuppressed ?? true)
    }

    func testSuppressedOperationsExcludedFromActiveChain() {
        let n1 = tree.recordOperation(CADOperation(type: .createPrimitive, description: "Box"))
        tree.recordOperation(CADOperation(type: .fillet, description: "Fillet"))
        tree.toggleSuppress(nodeID: n1.id)
        // La cadena activa excluye operaciones suprimidas
        let active = tree.activeChain
        XCTAssertEqual(active.count, 1) // solo Fillet visible
    }

    // MARK: - Rebuild scene

    func testRebuildSceneCreateAndDelete() {
        let ops: [CADOperation] = [
            CADOperation(type: .createPrimitive, description: "Box",
                        affectedModelIDs: []),
            CADOperation(type: .delete, description: "Delete Box",
                        affectedModelIDs: []),
        ]
        // Nota: delete necesita affectedModelIDs para funcionar
        var opsWithIDs = ops
        let modelID = UUID()
        opsWithIDs[1].affectedModelIDs = [modelID]

        let models = tree.rebuildSceneFromOperations(initialModels: [], operations: opsWithIDs)
        // createPrimitive crea un modelo, delete lo elimina → 0 modelos
        XCTAssertEqual(models.count, 0)
    }

    func testRebuildSceneMoveTransform() {
        let model = Model(name: "Test")
        let modelID = model.id
        let ops: [CADOperation] = [
            CADOperation(type: .move, description: "Move",
                        affectedModelIDs: [modelID],
                        parameters: ["tx": 1.0, "ty": 2.0, "tz": 3.0]),
        ]
        let result = tree.rebuildSceneFromOperations(initialModels: [model], operations: ops)
        XCTAssertEqual(result.count, 1)
        // La posición del modelo debería haber cambiado
        XCTAssertEqual(result[0].position.x, 1.0, accuracy: 0.001)
        XCTAssertEqual(result[0].position.y, 2.0, accuracy: 0.001)
        XCTAssertEqual(result[0].position.z, 3.0, accuracy: 0.001)
    }

    func testRebuildSceneMoveWithExistingTransform() {
        let model = Model(name: "Test")
        let modelID = model.id
        // Aplicar primer move
        let ops1: [CADOperation] = [
            CADOperation(type: .move, description: "Move1",
                        affectedModelIDs: [modelID],
                        parameters: ["tx": 1.0, "ty": 0, "tz": 0]),
        ]
        let after1 = tree.rebuildSceneFromOperations(initialModels: [model], operations: ops1)
        // Aplicar segundo move sobre el resultado
        let ops2: [CADOperation] = [
            CADOperation(type: .move, description: "Move2",
                        affectedModelIDs: [modelID],
                        parameters: ["tx": 2.0, "ty": 0, "tz": 0]),
        ]
        let after2 = tree.rebuildSceneFromOperations(initialModels: after1, operations: ops2)
        XCTAssertEqual(after2[0].position.x, 3.0, accuracy: 0.001)
    }

    func testRebuildSceneScale() {
        let model = Model(name: "Test")
        let modelID = model.id
        let ops: [CADOperation] = [
            CADOperation(type: .scale, description: "Scale",
                        affectedModelIDs: [modelID],
                        parameters: ["sx": 2.0, "sy": 1.0, "sz": 3.0]),
        ]
        let result = tree.rebuildSceneFromOperations(initialModels: [model], operations: ops)
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].scale.x, 2.0, accuracy: 0.001)
        XCTAssertEqual(result[0].scale.z, 3.0, accuracy: 0.001)
    }

    func testRebuildSceneGeometryOpsAreSkipped() {
        // Las operaciones que modifican geometría (extrude, fillet, etc.)
        // son manejadas por OCCT, no por rebuildSceneFromOperations
        let ops: [CADOperation] = [
            CADOperation(type: .sketchExtrude, description: "Extrude",
                        parameters: ["distance": 5.0]),
            CADOperation(type: .fillet, description: "Fillet",
                        parameters: ["radius": 0.3]),
        ]
        let result = tree.rebuildSceneFromOperations(initialModels: [], operations: ops)
        // No se crean ni destruyen modelos para ops de geometría
        XCTAssertEqual(result.count, 0)
    }

    // MARK: - Find node

    func testFindNode() {
        let n1 = tree.recordOperation(CADOperation(type: .createPrimitive, description: "A"))
        let n2 = tree.recordOperation(CADOperation(type: .extrude, description: "B"))
        XCTAssertNotNil(tree.findNode(with: n1.id))
        XCTAssertNotNil(tree.findNode(with: n2.id))
        XCTAssertNil(tree.findNode(with: UUID()))
    }

    func testClearResetsAllState() {
        tree.recordOperation(CADOperation(type: .createPrimitive, description: "A"))
        tree.recordOperation(CADOperation(type: .extrude, description: "B"))
        tree.clear()
        XCTAssertEqual(tree.operationCount, 0)
        XCTAssertTrue(tree.activeChain.isEmpty)
        XCTAssertFalse(tree.isDirty)
        XCTAssertNil(tree.currentNode)
        XCTAssertNil(tree.recomputeRequested)
        XCTAssertTrue(tree.rootNodes.isEmpty)
    }

    // MARK: - Parameter summary

    func testParameterSummary() {
        let op = CADOperation(type: .extrude, description: "E",
                              parameters: ["distance": 1.5, "taper": 0.0])
        let summary = op.parameterSummary
        XCTAssertTrue(summary.contains("distance"))
        XCTAssertTrue(summary.contains("1.50"))
    }

    func testParameterSummaryEmpty() {
        let op = CADOperation(type: .move, description: "M")
        XCTAssertEqual(op.parameterSummary, "")
    }

    // MARK: - beginOperation convenience

    func testBeginOperation() {
        let node = tree.beginOperation("Test Box", type: .createPrimitive,
                                        params: ["size": 10.0],
                                        affectedIDs: [UUID()])
        XCTAssertEqual(tree.operationCount, 1)
        XCTAssertEqual(node.operation.type, .createPrimitive)
        XCTAssertEqual(node.operation.parameters["size"], 10.0)
    }
}
