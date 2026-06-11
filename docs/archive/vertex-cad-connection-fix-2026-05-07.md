# Fix: Vertex CAD Connection

## Problema
CADSketchEngine.connectToScene() tenia 3 bloques de codigo comentados con el mensaje:
"TODO: Vertex struct currently lacks an 'id' property"

## Realidad
Vertex YA tenia `let id: UUID = UUID()` desde el inicio en Core/Engines/Mesh.swift.
Scene3D.configurePositionProvider() ya usaba `vertex.id` correctamente.

## Que se hizo
Se descomentaron 2 bloques en CADSketchEngine.connectToScene():

1. **entityPositionProvider** (linea 142): ahora compara `vertex.id == entityID`
2. **entityPositionUpdater** (linea 156): ahora busca por `vertex.id` y actualiza posicion

## Estado final
- CADSketchEngine → VertexProvider: `providePoints()` → Scene3D recibe puntos
- Scene3D → VertexUpdater: `updateMesh()` devuelve Mesh actualizado
- connectToScene() completa: provider y updater conectan constraints del CAD con vertices 3D

## Archivos modificados
- `Features/CADMode/CADSketchEngine.swift` — 2 bloques descomentados

## Archivos verificados (sin cambios necesarios)
- `Core/Engines/Mesh.swift` — Vertex.id ya correcto
- `Core/Engines/Scene3D.swift` — configurePositionProvider() ya correcto
