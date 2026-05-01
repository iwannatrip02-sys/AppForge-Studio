# Fase 6 Paso 2 — Integracion Constraints + CSG + Subdivision Slider
> 2026-04-30 01:10 UTC | 3 bugs corregidos de 4 pendientes

## Cambios Realizados

### 1. GeometryConstraintManager + Scene3D (Core/Managers/ y Models/)
**Antes:** GeometryConstraintManager tenia solo CRUD sin `resolveConstraints()`. CADSketchEngine (linea 14) llamaba a `constraintManager.resolveConstraints()` que no existia — fallo de compilacion garantizado. Scene3D tenia `var constraintManager` pero nunca la usaba en addModel() o addStroke().

**Ahora:**
- GeometryConstraintManager.swift: añadido `resolveConstraints()` con closures `entityPositionProvider` y `entityPositionUpdater` para acceso a entidades 3D. Solvers implementados: horizontal, vertical, distance, equal, midpoint. Angle y complejos como stub.
- Scene3D.swift: init() llama a `setupConstraintClosures()`, addModel() y addStroke() llaman a `constraintManager.resolveConstraints()` tras cada operacion.

### 2. CSGEngine con BSP Tree (Core/Engines/)
**Antes:** `union()` solo concatenaba vertices e indices. `subtract()` e `intersect()` eran stubs que retornaban mesh A o mesh vacia.

**Ahora:** Implementacion completa con BSP Tree:
- Clase `BSPNode` con plano, front, back, triangulos
- `buildBSP()` construye arbol recursivo (max depth 10, leaf si <5 triangulos)
- `classifyTriangle()`: front/back/coplanar/spanning
- `splitTriangle()`: corta triangulos contra un plano, retorna front y back
- `clipTriangles()`: clipa lista de triangulos contra BSP node
- `union()`: clip A contra BSP B + todos los triangulos de B
- `subtract()`: solo clip A contra BSP B (descarta B)
- `intersect()`: clip A contra BSP B + clip resultado contra BSP A

### 3. SculptModeView slider de subdivision (Features/SculptMode/)
**Antes:** Boton "Sub" hardcodeado a `levels: 1`. Sin control de nivel.

**Ahora:**
- `@State private var subdivisionLevels: Double = 2`
- Slider de 1 a 4 con step 1 (compatible con SubdivisionEngine que limita a 4)
- Boton "Aplicar" que llama a `subdivisionVM.subdivide(mesh, levels: Int(subdivisionLevels))`

### 4. (Pendiente) Compilacion local con xcodebuild
Requiere entorno macOS con Xcode y Satin framework instalado. No ejecutable en Windows.

## Archivos Modificados
| Archivo | Lineas | Cambio |
|---------|--------|--------|
| Core/Managers/GeometryConstraintManager.swift | ~180 | Anadido resolveConstraints(), 5 solvers, 2 closures |
| Models/Scene3D.swift | ~105 | setupConstraintClosures(), addModel/addStroke con resolveConstraints |
| Core/Engines/CSGEngine.swift | ~320 | BSP Tree completo con 3 operaciones booleanas |
| Features/SculptMode/SculptModeView.swift | ~80 | Slider 1-4 + boton Aplicar para subdivision |
| Features/CADMode/CADSketchEngine.swift | ~30 | Comentario actualizado (ahora resolveConstraints existe) |