# Usabilidad Real de AppForge Studio — 2026-05-11

> Análisis basado en el proyecto real en `ios-app/AppForgeStudio/` (NO en la raíz vacía)

## ⚠️ Corrección crítica

El análisis anterior de usabilidad (nivel 2/10) era INCORRECTO porque estaba leyendo la raíz del workspace que solo tenía 5 engines sueltos. El **proyecto real** tiene 47 engines y 7 modos de UI.

---

## Inventario real del código existente

### Core/Engines/ — 47 archivos

| Categoría | Cantidad | Archivos clave |
|-----------|----------|----------------|
| **Render** | 12 | SatinRenderer, SatinRendererView, SatinMesh, Scene3D, SceneRenderer, IBLPipeline, PBRMaterial, PBRMaterialUniforms, MaterialData, MaterialEditorView, MaterialPresets, TestCube |
| **CAD sólido** | 12 | CSGEngine, BooleanEngine, BevelEngine, ChamferEngine, ExtrusionEngine, FilletEngine, LoftEngine, ShellEngine, SweepEngine, SubdivisionEngine, OCCTEngine, SolverSwift |
| **Deformers** | 9 | Deformer (base), CreaseDeformer, FlattenDeformer, GrabDeformer, InflateDeformer, MoveDeformer, PinchDeformer, SmoothDeformer, TwistDeformer |
| **Animación** | 3 | AnimationEngine, AnimationPlaybackController, MorphEngine |
| **Escultura** | 4 | SculptEngine, BrushEngine, BrushStroke, PincelRenderer |
| **Utilidades** | 7 | LODManager, MeasureEngine, Mesh, Model3D, Sketch2D, SDFEngine, AssemblyEngine |

### Features/ — 7 modos de UI

| Modo | Archivos | Estado estimado |
|------|----------|-----------------|
| **CADMode** | 12 archivos | ✅ Más completo — CADModeView, CADSketchEngine, CADSketchView, CADTool, ConstraintOverlayView, ContentView, GeometryConstraintManager, GestureHandler, HitTestEngine, PencilSketchView, SketchTool, + Tools/ y Views/ |
| **PaintMode** | 2 archivos | 🟡 PaintRenderer.swift, MaterialEditorPBRView.swift |
| **AnimationMode** | 1 archivo | 🟡 AnimationModeView.swift |
| **SculptMode** | ? | 🟡 No explorado |
| **ExportMode** | ? | 🟡 No explorado |
| **RenderMode** | ? | 🟡 No explorado |
| **HybridMode** | ? | 🟡 No explorado |

### Sources/ — 6 subdirectorios
AnimationEngine/, CADCore/, ExportService/, RenderEngine/, SculptEngine/, UIComponents/

---

## Análisis de usabilidad (proyecto real)

### Lo que SÍ existe y funciona conceptualmente

1. **Pipeline de render completo**: Scene3D + SatinRenderer + PBRMaterial + IBLPipeline + LODManager. El stack gráfico está montado con Metal via Satin.
2. **Motor CAD sólido**: 12 engines cubriendo operaciones booleanas (CSG/Boolean), extrusión, loft, sweep, chaflanes, subdivisión, y binding con OCCT. Incluye SolverSwift para constraints y Sketch2D para dibujo 2D.
3. **Modo CAD completo**: 12 archivos en Features/CADMode/ con sketch engine, constraint overlay, gesture handler, hit testing, tools y content view. Es el modo más maduro.
4. **Deformación procedural**: 9 deformers listos para escultura (Grab, Inflate, Twist, Smooth, Flatten, Pinch, Move, Crease).
5. **Animación funcional**: AnimationEngine con keyframes, interpolación lineal + slerp, clips y loop. Conectado a SatinRenderer para playback.

### Lo que falta para una app usable

1. **Sin Scene3D principal visible**: No hay una vista raíz que muestre un modelo 3D renderizado en pantalla. El ContentView.swift de CADMode es específico del modo CAD.
2. **Sin navegación entre modos**: 7 modos UI existen como carpetas separadas pero no hay un `App.swift` o `MainTabView` que los orqueste. El usuario no puede cambiar entre CAD, Paint, Sculpt y Animation.
3. **Modos sin contenido**: PaintMode tiene 2 archivos, AnimationMode 1, y Sculpt/Export/Render/Hybrid no los exploré aún. Probablemente son esqueletos.
4. **Sin modo Paint 3D funcional**: Hay PincelRenderer.swift y BrushStroke.swift pero falta la UI de pinceles (tamaño, opacidad, color, tipo de brush).

### Escala de usabilidad real: 5/10

No es 2/10 como dije antes (ese análisis estaba basado en datos equivocados). El motor está sólido, el modo CAD está bastante completo con sketch + constraints + gestos. Pero la app no está ensamblada como producto usable — le falta el pegamento de UI.

---

## Próximos pasos recomendados

1. **Leer ContentView.swift** de CADMode (12 archivos, sugiere que es la vista principal del modo más completo)
2. **Leer los modos no explorados**: SculptMode, ExportMode, RenderMode, HybridMode
3. **Buscar App.swift o entry point** del proyecto (probablemente en Sources/ o Build/)
4. **Identificar qué conecta los 7 modos** — si existe un sistema de navegación o tab bar
5. **Hacer ingeniería inversa del Scene3D** que renderiza los modelos

Los engines están, el render está, el CAD está casi completo. Lo que falta es el ensamblaje de UI.
