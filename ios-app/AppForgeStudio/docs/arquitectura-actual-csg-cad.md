# Arquitectura Actual del AppForge Studio iOS

> Generado: 2026-05-12 | Fuente: inspección directa del workspace

## Estructura del Proyecto

Package.swift compila **4 directorios raíz** como un solo target `.executableTarget`:
- `Core/` — infraestructura compartida (CSG, CAD, Engines, Managers, Shaders, Theme, UI)
- `Features/` — 7 modos de la app: AnimationMode, CADMode, ExportMode, HybridMode, PaintMode, RenderMode, SculptMode
- `Sources/` — estructura legacy (6 carpetas, mayoría vacías o con poco contenido)
- `Preview/`, `Resources/` — preview y assets

## Core/CSG — Módulo de Geometría Constructiva (COMPLETO ✅)

### Archivos (4):
| Archivo | Estado | Función |
|---------|--------|---------|
| `BSPNode.swift` | ✅ Completo | Árbol binario de partición espacial con clasificación coplanar/front/back/spanning |
| `CSGOperation.swift` | ✅ Completo | Enum con union/difference/intersection usando clipping BSP |
| `Polygon3D.swift` | ✅ Completo | Conversión Mesh ↔ polígonos con triangulación |
| `Shape.swift` | ✅ Completo | Wrapper con primitivas (box, sphere, cylinder, cone, torus, plane) + operaciones booleanas |

### APIs booleanas expuestas:
```swift
let cube = Shape.box(width: 2, height: 2, depth: 2)
let sphere = Shape.sphere(radius: 1.5)
let result = cube.difference(sphere)  // CSG con BSP tree
```

### Algoritmo CSG:
1. Convertir ambas meshes a `[Polygon3D]`
2. Construir BSP tree para cada mesh
3. Clip polígonos de A contra árbol de B (y viceversa)
4. Combinar según operación: union (frontA + backB), difference (frontA + frontB), intersection (backA + backB)
5. Re-ensamblar a Mesh vía triangulación

## Features/CADMode — Modo CAD (COMPLETO ✅)

### Archivos (10+):
| Archivo | Función |
|---------|---------|
| `CADModeView.swift` | View principal del modo CAD |
| `CADSketchEngine.swift` | Motor de sketch 2D |
| `CADSketchView.swift` | View de sketch interactivo |
| `CADTool.swift` | **Enum con 25 herramientas** incluyendo booleanUnion/Subtract/Intersect |
| `ConstraintOverlayView.swift` | Overlay visual de constraints |
| `ContentView.swift` | Content view del modo |
| `GeometryConstraintManager.swift` | Gestor de constraints geométricas |
| `GestureHandler.swift` | Manejo de gestos táctiles |
| `HitTestEngine.swift` | Hit testing 3D para selección |
| `PencilSketchView.swift` | Sketch con Apple Pencil |
| `SketchTool.swift` | Herramientas de sketch (line, circle, rect, arc) |
| `Tools/` | Subcarpeta de herramientas adicionales |
| `Views/` | Subcarpeta de views adicionales |

## Fuentes de Datos / Decisiones (del brain y TODO.md)

### BRAIN.md dice:
- Sources real es PLANO (AnimationEngine, CADCore, ExportService, RenderEngine, SculptEngine, UIComponents)
- backup_sources/ tiene codigo que no esta en Sources activo
- Satin (framework Metal), Assimp (import/export), ModelIO (assets 3D nativos) son dependencias clave

### TODO.md — Items pendientes:
1. Fase 5: Validar exportacion STEP con modelo real
2. Fase 6: Unit tests para AnimationEngine
3. Fase 6: Tests de integracion render + animacion

### Gap identificado: CSGBooleanView.swift (mencionado en project_tree previo) sincroniza CADTool con CSGOperation. Necesito revisar su contenido para confirmar que la UI boolean ya esta conectada al CSG backend.

## Próximas lecturas necesarias (3 archivos):
1. `Features/CADMode/Views/CSGBooleanView.swift` — UI de operaciones booleanas
2. `Features/CADMode/CADModeView.swift` — para ver cómo integra las herramientas
3. `Features/CADMode/Tools/` — contenido de la subcarpeta
