# Sesion 12 de Mayo 2026 — AppForge Studio

## Estado del proyecto

### CSG booleano — COMPLETO
Archivos verificados en disco:
- **Core/CSG/BSPNode.swift** — Arbol BSP con classify, split, init desde poligonos. Selecciona mejor splitter heuristico (min diff front/back).
- **Core/CSG/CSGOperation.swift** — Enum con .union, .difference, .intersection. Cada uno llama a BSPNode y aplica clipping.
- **Core/CSG/Polygon3D.swift** — Poligono 3D con plano, normal, vertices, metodo split.
- **Core/CSG/Shape.swift** — Primitivas (box, cylinder, sphere, plane) + metodos union/difference/intersection que delegan a CSGOperation.
- **Features/CADMode/CADTool.swift** — Enum con .booleanUnion, .booleanSubtract, .booleanIntersect, iconos SF Symbols.
- **Features/CADMode/CADModeView.swift** — Toolbar con los 3 booleanos en cadTools.
- **Tests/CSGTests.swift** — 6 tests: box primitiva (36 indices), cylinder, sphere, union, difference, intersection.

### Export STEP
- **Features/ExportMode/ExportServiceSTEP.swift** — Genera STEP valido (ISO-10303-21) desde sketches 2D con CARTESIAN_POINT, DIRECTION, VECTOR, LINE, EDGE_CURVE.
- **Features/ExportMode/ExportView.swift** — UI con botones OBJ/STL (fileExporter), alerta STEP, progress view, confetti. **Falta boton dedicado STEP 3D** para exportar mallas 3D.
- **Tests/ExportServiceTests.swift** — testExportToSTEP() valida export con TestCube real.

### Animacion — COMPLETO
- **Core/Engines/AnimationEngine.swift** — Keyframe, Clip, evaluateAnimation.
- **Tests/AnimationEngineTests.swift** — 7 tests XCTest.
- **Tests/AnimationPlaybackTests.swift** — Integracion render+animacion (playback lifecycle, seek bounds, progress).

### Proximas acciones
1. swift build en macOS (bloqueado: requiere Mac)
2. Agregar boton export STEP 3D en ExportView (exportar malla 3D a STEP)
3. Preview visual de CSG antes de aplicar operacion
4. Test integracion CSG + ExportService
5. Profiling CSG para mallas >1000 poligonos
