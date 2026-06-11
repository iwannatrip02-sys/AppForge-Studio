# Estado Real CAD: Diagnóstico de Conexiones (2026-05-07)

## Hallazgos tras leer 6 archivos clave:

### ✅ YA CONECTADO - CADHistoryTree
- CADSketchEngine.swift linea 4: `@Published var historyTree = CADHistoryTree()`
- CADHistoryTree.swift completo con 16 tipos de operacion, undo/redo, CADNode tree
- No requiere cambios

### ✅ YA CONECTADO - Pipeline sketch→solver→extrude
- CADSketchEngine tiene `constraintManager` y `resolveConstraints(scene:)` ya integrado
- CADModeView.swift llama `sketchEngine.resolveConstraints(scene: canvasVM.scene)` en .onAppear
- extrude fluye: CADSketchView produce mesh → CADModeView recibe `extrudedMesh` → lo agrega a scene
- ExtrusionEngine.swift opera sobre Mesh puro, retorna Mesh nuevo

### ❌ FALTA: id: UUID en Vertex
- Mesh.swift struct Vertex NO tiene `id: UUID`
- SketchPoint, SketchLine, etc. SÍ tienen id:UUID (CADSketchEngine.swift)
- Se necesita para provider/updater 3D

### ❌ FALTA: provider/updater en Scene3D
- canvasVM.scene es Scene3D sin propiedades provider/updater
- Habria que extender Scene3D o crear un wrapper

## Proximas acciones reales:
1. Vertex.swift: agregar `let id: UUID = UUID()`
2. Scene3D.swift (o equivalente): agregar provider/updater opcionales
3. CADModeView.swift: en .onAppear conectar historyTree a scene si existe
4. competitive-edge-2026.md: D1-D8 ya documentados, priorizar AI-asistente (D1) + real-time collab (D2)
