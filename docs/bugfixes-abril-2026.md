# Bugfixes - Abril 2026

## Resumen
Se corrigieron 2 bugs estructurales en el codigo de AppForge Studio que impedian la compilacion y el correcto funcionamiento de operaciones CAD.

## Bug 1: BooleanEngine.meshToShape - bounding box fallback

**Archivo:** `Features/CADMode/Tools/BooleanEngine.swift`

**Problema:** La funcion `meshToShape()` intentaba construir un poligono desde los vertices de la malla usando `Shape.polygon(vertices:)` que solo funciona para poligonos planos. Al fallar, creaba una caja aproximada (bounding box) del tamano de la malla, perdiendo toda la geometria real. Las operaciones booleanas `difference()` y `intersection()` daban resultados incorrectos porque operaban sobre una caja en vez de la forma real.

**Solucion:** Se reemplazo el bloque por una iteracion sobre `mesh.indices` en grupos de 3 para construir triangulos reales. Cada triangulo se convierte en `Shape.face(p0:p1:p2:)`, y se combinan en `Shape.shell(faces:)` y `Shape.solid(shell:)`. El bounding box solo se usa como fallback dentro del `catch` del `do-catch`.

**Cambio:** ~40 lineas reemplazadas.

## Bug 2: CADModeView - referencia a `canvasVM.currentMesh` inexistente

**Archivo:** `Features/CADMode/CADModeView.swift`

**Problema:** Dos referencias a `canvasVM.currentMesh` que no existe como propiedad de `CanvasViewModel`:
1. `onChange(of: extrudedMesh)` hacia `canvasVM.currentMesh = mesh` -> ahora usa `canvasVM.scene.addModel(Model(name:meshes:))`
2. `toolVM.executeTool(mesh: &canvasVM.currentMesh)` -> ahora opera sobre `canvasVM.scene.models[0].meshes[0]`

**Solucion:** 
- La extrusion de sketches ahora crea un `Model` con nombre unico (UUID truncado) y lo anade a la escena via `addModel()`.
- La ejecucion de herramientas CAD (uniones, cortes, intersecciones) ahora obtiene la primera malla del primer modelo de la escena, la hace mutable, ejecuta la herramienta y reasigna el resultado.

**Cambio:** ~15 lineas reemplazadas.

## Archivos modificados
- `ios-app/AppForgeStudio/Features/CADMode/Tools/BooleanEngine.swift`
- `ios-app/AppForgeStudio/Features/CADMode/CADModeView.swift`

## Pendiente
- Verificar compilacion en Xcode (depende de la firma exacta de `Shape.face()` y `Shape.shell()` en OCCTSwift)
- Conectar AnimationEngine con AppState (weak var existe pero no se usa)
- Conectar SubdivisionEngine a UI
