# Estado Real de AppForge Studio — 2026-05-11

## ⚠️ Error detectado: Dos workspaces

Estuve trabajando en `appforge-studio/` (raíz) con 5 engines CAD sueltos en `Sources/CADCore/`.
El proyecto real está en `appforge-studio/ios-app/AppForgeStudio/` con su propio `Package.swift`,
`Core/Engines/`, `Features/`, BRAIN.md y TODO.md.

**Mi análisis anterior de usabilidad es INCORRECTO** porque usé datos de la raíz, no del proyecto real.

---

## Inventario completo del proyecto real

### Core/Engines/ (47 archivos)

| Categoría | Archivos | Cantidad |
|-----------|----------|----------|
| **Render** | SatinRenderer.swift, SatinRendererView.swift, SatinMesh.swift, Scene3D.swift, SceneRenderer.swift, IBLPipeline.swift, PBRMaterial.swift, PBRMaterialUniforms.swift, MaterialData.swift, MaterialEditorView.swift, MaterialPresets.swift, TestCube.swift | 12 |
| **Animación** | AnimationEngine.swift, AnimationPlaybackController.swift, MorphEngine.swift | 3 |
| **CAD sólido** | CSGEngine.swift, BooleanEngine.swift, BevelEngine.swift, ChamferEngine.swift, ExtrusionEngine.swift, FilletEngine.swift, LoftEngine.swift, ShellEngine.swift, SweepEngine.swift, SubdivisionEngine.swift, OCCTEngine.swift, SolverSwift.swift | 12 |
| **Deformers** | Deformer.swift, CreaseDeformer.swift, FlattenDeformer.swift, GrabDeformer.swift, InflateDeformer.swift, MoveDeformer.swift, PinchDeformer.swift, SmoothDeformer.swift, TwistDeformer.swift | 9 |
| **Escultura** | SculptEngine.swift, BrushEngine.swift, BrushStroke.swift, PincelRenderer.swift | 4 |
| **Utilidades** | LODManager.swift, MeasureEngine.swift, Mesh.swift, Model3D.swift, Sketch2D.swift, SDFEngine.swift, AssemblyEngine.swift | 7 |

### Features/ (7 modos de UI)

| Modo | Archivos | Estado |
|------|----------|--------|
| **CADMode** | CADModeView.swift, CADSketchEngine.swift, CADSketchView.swift, CADTool.swift, ConstraintOverlayView.swift, ContentView.swift, GeometryConstraintManager.swift, GestureHandler.swift, HitTestEngine.swift, PencilSketchView.swift, SketchTool.swift + Tools/ + Views/ | **Completo** con sketch 2D, constraints y gestos |
| **PaintMode** | MaterialEditorPBRView.swift, PaintRenderer.swift | Básico — editor PBR + render |
| **AnimationMode** | AnimationModeView.swift | **Completo** — timeline, play/pause, slider (Fase 4) |
| **SculptMode** | (pendiente listar) | Sin explorar aún |
| **ExportMode** | (pendiente listar) | Sin explorar aún |
| **RenderMode** | (pendiente listar) | Sin explorar aún |
| **HybridMode** | (pendiente listar) | Sin explorar aún |

### Core/CAD/
- ConstraintEngine.swift — sistema de constraints paramétricos
- SnapEngine.swift — snapping geométrico

### Sources/
- AnimationEngine/ — implementación legacy/alternativa
- CADCore/ — CADModeView, GeometryConstraintManager, LoopCutEngine
- ExportService/ — exportación STEP/STL/OBJ
- RenderEngine/ — PaintRenderer
- SculptEngine/ — SculptModeView
- UIComponents/ — componentes UI reutilizables

### Pipeline de compilación
- `Package.swift` con iOS 17+, Satin (render Metal), OCCTSwift (CAD kernel)
- CI: `.github/workflows/build-ios.yml` e `ios-build.yml`

---

## Usabilidad real (corregida)

Basado en el proyecto real, NO en la raíz:

### Lo que YA funciona y es navegable:
1. **CADMode** — interfaz completa con sketch 2D a lápiz, constraints paramétricos, detección de hits, gestos multi-touch. Es el modo más avanzado del proyecto.
2. **AnimationMode** — timeline funcional con togglePlayPause, slider de tiempo, keyframes, clips y loop. Fase 4 completada según BRAIN.md.
3. **PaintMode** — selector de materiales PBR con editor, renderer de pintura.
4. **Render 3D** — Scene3D con modelo, cámara, luces, pipeline PBR completo vía Satin/Metal.

### Lo que NO existe aún (brechas de usabilidad):
1. **No hay Scene3DView o SatinRendererView real** en Features — el render 3D vive en Core/Engines pero no está envuelto en una UI SwiftUI que el usuario pueda ver. CADModeView probablemente ya lo renderiza, pero AnimationModeView y PaintModeViews no muestran previsualización 3D.
2. **No hay navegación entre modos** — no existe un `AppView.swift` o `MainTabView.swift` que permita cambiar entre CAD, Paint, Sculpt, Animation, Export.
3. **Modo Paint 3D sin brush 3D real** — PaintRenderer y PincelRenderer existen en Core/Engines, pero PaintMode solo tiene un editor de materiales (PBR), no un canvas 3D para pintar sobre modelos.
4. **SculptMode, ExportMode, RenderMode, HybridMode** — sus vistas existen como directorios pero no sé qué contienen exactamente (el READ_BUDGET me cortó la exploración).

### Puntuación de usabilidad realista:
**4/10** — Hay MUCHO más de lo que detecté en el workspace incorrecto. Los engines son sólidos y CADMode tiene interfaz funcional. Pero falta la app como producto: sin navegación, sin vista 3D central, y 4 de 7 modos no están verificados.

---

## Causa raíz del error de dualidad

El workspace de `project_context` apunta a `C:\Users\USUARIO\Projects\appforge-studio` (raíz),
pero el BRAIN.md del proyecto real dice:
```
## Ruta workspace
C:\Users\USUARIO\Projects\appforge-studio\ios-app\AppForgeStudio
```

Gotchi recibe el workspace de registy (raíz), pero el proyecto real vive en el subdirectorio.
Hay que corregir el workspace del proyecto en el registry para que apunte a `ios-app/AppForgeStudio/`.

---

## Próximos pasos recomendados

1. **Corregir workspace del proyecto** → apuntar a `ios-app/AppForgeStudio/`
2. **Leer los 4 modos faltantes** (Sculpt, Export, Render, Hybrid)
3. **Leer archivos clave**: ContentView.swift (punto de entrada), Scene3D.swift, SatinRenderer.swift
4. **Construir sistema de navegación** entre modos
5. **Verificar compilación** con Swift Package Manager
