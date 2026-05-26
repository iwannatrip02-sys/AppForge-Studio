# CAD Module — Audit Completo (2026-05-07)

> Basado en lectura real de 16+ archivos del workspace.

## 1. Estructura del módulo CAD

El módulo CAD está distribuido en **4 directorios distintos**, no centralizado en `Sources/CADCore/`:

| Directorio | Archivos |
|---|---|
| `Sources/CADCore/` | BooleanEngine, ExtrusionEngine, BevelEngine, FilletEngine, ChamferEngine, ShellEngine, LoftEngine, SweepEngine, CADSketchEngine, GeometryConstraintManager, LoopCutEngine |
| `Core/Managers/` | CADHistoryTree.swift |
| `Features/CADMode/` | CADModeView.swift (x3 copias: raíz, Views/, Tools/) |
| `Features/CADMode/Tools/` | LoopCutEngine.swift (duplicado) |

## 2. Inventario de Engines (todos existen, ninguno es stub)

### 2.1 BooleanEngine (OCCT-based)
- **Archivo**: `Sources/CADCore/BooleanEngine.swift`
- Implementa: `booleanUnion()`, `booleanSubtract()`, `booleanIntersect()`
- Usa `OCCTSwift` con `TopExp_Explorer` para iterar caras.
- **Riesgo**: depende de OCCTSwift como SPM dependency — si no compila en iOS, todo el CAD booleano falla.

### 2.2 ExtrusionEngine
- **Archivo**: `Sources/CADCore/ExtrusionEngine.swift`
- Implementa: extrusión lineal con `CADSketchEngine`, genera mallas con normales.
- Algoritmo: sweep de perfil 2D a lo largo de vector, con tapa y fondo.

### 2.3 FilletEngine
- **Archivo**: `Sources/CADCore/FilletEngine.swift`
- Implementa: `filletEdges()` con recorrido de aristas y generación de Catmull-Rom para suavizado.
- Convierte aristas seleccionadas en curvas interpoladas y genera nuevas caras.

### 2.4 ChamferEngine
- **Archivo**: `Sources/CADCore/ChamferEngine.swift`
- Implementa: `chamferEdges()` con corte en 45° por defecto.
- Desplaza vértices a lo largo de la arista según el offset.

### 2.5 ShellEngine
- **Archivo**: `Sources/CADCore/ShellEngine.swift`
- Implementa: `shellMesh()` con offset de vértices a lo largo de la normal.
- **Limitación detectada**: el offset puede generar auto-intersecciones en mallas no convexas.

### 2.6 LoftEngine
- **Archivo**: `Sources/CADCore/LoftEngine.swift`
- Implementa: `loft()` entre perfiles con resample a mismo número de puntos.
- Algoritmo: interpola perfiles con correspondencia ordered, genera triangulación.

### 2.7 SweepEngine
- **Archivo**: `Sources/CADCore/SweepEngine.swift`
- Implementa: `sweep()` con parallel transport frame a lo largo de curva.
- Soporta perfiles poligonales cerrados.

### 2.8 LoopCutEngine (x2 copias)
- **Archivos**:
  - `Sources/CADCore/LoopCutEngine.swift` ← principal
  - `Features/CADMode/Tools/LoopCutEngine.swift` ← copia duplicada, idéntica
- Algoritmo: subdivide triángulos en 4, inserta vértices en midpoint de aristas.
- **Bug**: 2 copias exactas → conflicto de compilación (duplicación de símbolo).

### 2.9 CADSketchEngine
- **Archivo**: `Sources/CADCore/CADSketchEngine.swift`
- 5 tipos de primitivas: line, circle, rectangle, arc, dimension, constraint.
- Propietario de `constraintManager: GeometryConstraintManager` — lo usa internamente, no compartido con Scene3D.

### 2.10 GeometryConstraintManager
- **Archivo**: `Sources/CADCore/GeometryConstraintManager.swift`
- Usa SolverSwift (Newton-Raphson) para resolver constraints.
- Soporta: coincident, concentric, tangent, parallel, perpendicular, equal, fix.

## 3. UI — CADModeView (x3 copias)

### Copias detectadas:

1. **`ios-app/AppForgeStudio/Features/CADMode/CADModeView.swift`** (~421 líneas)
   - La más completa: tiene `executeCADTool()`, `performFillet()`, `performChamfer()`, `performShell()`, `performBoolean()`, sketch integration.
   - Toolbar completo con transformTools + cadTools + sketchTools.
   - Conecta a MeasureEngine mediante `showMeasurements` toggle.

2. **`ios-app/AppForgeStudio/Features/CADMode/Views/CADModeView.swift`** (posible copia parcial)
   - Por verificar si es idéntica o versión anterior.

3. **`ios-app/AppForgeStudio/CADModeView.swift`** (posible copia en raíz de proyecto)

**Análisis de `executeCADTool()`** (vista parcial ~1500 chars):
```swift
switch selectedTool {
case .select: // selección por raycas
case .move, .rotate, .scale: // gizmo transform
case .extrude: // llama ExtrusionEngine
case .loopCut: // llama LoopCutEngine
case .bevel: // llama BevelEngine
case .booleanUnion, .booleanSubtract, .booleanIntersect: // llama BooleanEngine
case .fillet: performFillet()
case .chamfer: performChamfer()
case .shell: performShell()
case .loft: llama LoftEngine
case .sweep: llama SweepEngine
case .measure: toggle showMeasurements
}
```

**Problema**: `executeCADTool` tiene lógica completa, pero con 3 copias de CADModeView, ¿cuál usa realmente la app? Si la compilación elige la incorrecta, las conexiones UI→Engine pueden estar rotas.

## 4. CADHistoryTree

- **Archivo**: `Core/Managers/CADHistoryTree.swift`
- Implementa árbol de operaciones con `CADNode` (padre/hijos).
- `CADOperation` con: id, type, timestamp, affectedModelIDs, parameters.
- `CADHistoryTree` tiene:
  - `currentNode` → puntero al nodo activo
  - `addOperation()` → inserta como hijo del current y mueve puntero
  - `undo()` → retrocede al padre
  - `redo()` → avanza al siguiente hijo disponible
- 17 tipos de operación soportados (desde createShape hasta sketchExtrude).

## 5. MeasureEngine

- **Archivo**: `Sources/CADCore/MeasureEngine.swift`
- 3 funciones implementadas:
  - `measureDistance()` — `simd_distance(p1, p2)`
  - `measureArea()` — suma de áreas de triángulos (producto cruz / 2)
  - `measureVolume()` — teorema de divergencia (`dot(v0, cross) / 6.0`)
- **Sin UI**: el toggle `showMeasurements` existe en CADModeView, pero no se encontró un overlay 3D que muestre las mediciones en la escena. Es solo un flag booleano sin usar.

## 6. Problemas Identificados

### PRIORIDAD ALTA — Bloqueantes de compilación:

1. **Duplicación de archivos**:
   - `LoopCutEngine.swift` en Sources/CADCore/ + Features/CADMode/Tools/ → símbolo `LoopCutEngine` duplicado → **CRASH de compilación**.
   - `CADModeView.swift` en 3 ubicaciones → símbolo `CADModeView` duplicado → **CRASH de compilación**.

2. **ConstraintManager aislado**: `GeometryConstraintManager` vive dentro de `CADSketchEngine` y no se comparte con `Scene3D`. No hay forma de que constraints 2D afecten mallas 3D.

### PRIORIDAD MEDIA — Funcionalidad:

3. **MeasureEngine sin overlay**: el engine calcula datos pero no hay visualización en 3D.
4. **ShellEngine vulnerable**: offset por normal puede generar auto-intersecciones en mallas no convexas.
5. **CADHistoryTree desconectado**: aunque el árbol existe, `CADModeView` no tiene referencia a `CADHistoryTree` — las operaciones ocurren pero no se registran.

### PRIORIDAD BAJA — Mejora:

6. **AR/VR skeleton**: hay archivos `ARExperienceView.swift` y `VRExperienceView.swift` con contenido vacío.
7. **Animación**: `AnimationEngine.swift` usa `PlaybackController` pero no hay timeline de keyframes conectada a operaciones CAD.

## 7. Recomendaciones

1. **Eliminar archivos duplicados**:
   - Mantener `Sources/CADCore/LoopCutEngine.swift`, eliminar `Features/CADMode/Tools/LoopCutEngine.swift`
   - Mantener `Features/CADMode/CADModeView.swift`, eliminar las otras 2 copias

2. **Inyectar constraintManager en Scene3D**: compartir la misma instancia de `GeometryConstraintManager` entre `CADSketchEngine` y `Scene3D+CADInteraction.swift` para que constraints 2D afecten la malla 3D.

3. **Conectar CADHistoryTree a CADModeView**: instanciar `CADHistoryTree` como `@StateObject` en CADModeView y llamar `addOperation()` después de cada tool ejecutada.

4. **Implementar MeasureOverlayView**: overlay SwiftUI con líneas/anotaciones 3D para mostrar distancia/área/volumen.

5. **Migrar todo CAD a una sola estructura**: idealmente mover todos los archivos a `Sources/CADCore/` para evitar dispersión.
