# Analisis Completo: AppForge Studio iOS -> App Real y Funcional

> Fecha: 2026-05-11
> Base: C:\Users\USUARIO\Projects\appforge-studio\ios-app\AppForgeStudio

---

## 1. QUE TENEMOS (INVENTARIO REAL)

### Package.swift
- **Targets**: AppForgeStudio + Tests
- **Dependencias**: Satin (0.3.0, fork propio en ../satin/), OCCTSwift (bindings Open CASCADE)
- **Entry point esperado**: Sources/AppForgeStudio/AppForgeStudioApp.swift

### Core/Engines/ (47 engines funcionales)
Render: SatinRenderer, PBRMaterial, IBLPipeline, MetalRenderPipeline, Scene3D
Paint: PaintRenderer, PaintStrokeEngine, PaintUndoManager, PaintTextureGenerator
Sculpt: 8 deformers (Smooth, Inflate, Pinch, Grab, Flatten, Crease, Twist, Move)
CAD: 12 operaciones (Extrude, Revolve, Loft, Boolean (Union/Difference/Intersect), Shell, Fillet, Chamfer, Thicken, Section, Sweep, Helix, Split)
Animation: AnimationEngine, KeyframeManager, TimelineController, InterpolationEngine

### Core/UI/
- **ContentView.swift** (root view real, usa Metal+SatinView, tiene mode selector + undo/redo + theme)
- ViewModels/ (varios VMs de modos individuales)
- **CanvasViewModel.swift NO EXISTE** en proyecto real (solo en backup_sources con estructura vieja)

### Core/Managers/
- RenderManager.swift - orquesta SatinRenderer + escena
- AnimationEngine.swift - keyframe + timeline
- PaintEngine.swift - strokes + texturas PBR
- SculptEngine.swift - deformers + simetria
- SessionManager.swift - undo/redo global

### Core/Services/
- ExportService.swift - STL/OBJ
- ExportServiceSTEP.swift - STEP (OCCTSwift)
- ARQuickLookView.swift

### Features/ (7 modos UI)
1. **CADMode/** (12 archivos) - SketchView + ConstraintPanel + ExtrudeSheet + BooleanPicker + GestureHandler + HitTestEngine
2. **ExportMode/** (3 archivos) - ExportView + ExportServiceSTEP + ARQuickLookView
3. **SculptMode/** - Brushes/ (6 pinceles), SymmetryConfig, DynTopo
4. **PaintMode/** - PBR editor, layers
5. **AnimationMode/** - TimelineView + KeyframeEditor + AnimationList
6. **RenderMode/** - Configuracion de render
7. **HybridMode/** - Combinacion CAD + sculpt

### Sculpting/
- Deformers/ (8 operaciones)
- Brushes/ (Standard, Smooth, Inflate, Pinch, Grab, Crease)
- Symmetry.swift

### Models/
- SDF/ (Signed Distance Field operations)
- Assemblies/ (ensamblajes)
- Mesh formats

### Tests/ (6 archivos)
- AnimationEngineTests, CADOperationTests, ExportServiceTests, PaintEngineTests, Scene3DTests, SculptEngineTests

### backup_sources/AppForgeStudio/
- AppForgeStudioApp.swift COMPLETO (entry point real, usa CanvasView + ThemeManager)
- ContentView.swift COMPLETO (root view con modos + renders)
- CanvasViewModel.swift (version ANTERIOR - necesita actualizacion)
- ThemeManager.swift
- AppForgeStudio.entitlements
- Assets y plist

---

## 2. QUE FALTA (GAPS CRITICOS)

### GAP #1 - BLOQUEANTE: App NO compila
- **Package.swift** busca `Sources/AppForgeStudio/AppForgeStudioApp.swift`
- Ese archivo esta en `backup_sources/AppForgeStudio/`, NO en `Sources/`
- Solucion: Mover backup_sources/AppForgeStudio/* a Sources/AppForgeStudio/

### GAP #2 - BLOQUEANTE: CanvasViewModel no existe
- ContentView.swift (en Core/UI/) importa `@EnvironmentObject var canvasVM: CanvasViewModel`
- CanvasViewModel.swift NO existe en Sources/ ni en Core/UI/
- backup_sources/AppForgeStudio/ContentView.swift tiene su PROPIO CanvasViewModel inline (version vieja)
- Solucion: Crear CanvasViewModel.swift en Core/UI/ViewModels/ con la estructura que ContentView espera

### GAP #3 - Cableado faltante
- AppForgeStudioApp.swift crea `CanvasView()` pero necesita `wrapping CanvasView in NSHostingView` o similar
- Los ViewModels de Features/ no estan conectados al root ViewModel
- SatinRenderer necesita SatinView (MTKView wrapper) que ContentView ya usa pero falta import

### GAP #4 - UX no pulida (4/10)
- Sin onboarding tutorial
- Gestos multi-touch no implementados (pinch para zoom, dos dedos para orbit)
- Snapping magnetico para CAD (puntos, ejes, planos)
- Feedback haptico contextual
- Undo/redo visual (el motor existe pero no esta en UI)
- Menus contextuales (long-press en objeto -> opciones)

### GAP #5 - Sin testing real
- Tests existen como archivos pero no estan actualizados para la estructura actual
- No hay CI/CD configurado

---

## 3. PLAN EN 3 FASES PARA APP FUNCIONAL

### FASE 1: ENSAMBLAJE (1-2 dias)
**Objetivo: swift build pasa sin errores**

1. **Mover archivos**: backup_sources/AppForgeStudio/* -> Sources/AppForgeStudio/
   - Mantener estructura de Sources/ existente, fusionar archivos
2. **Crear CanvasViewModel.swift** en Core/UI/ViewModels/ con:
   - `@Published var currentMode: CanvasMode`
   - `@Published var selectedObject: UUID?`
   - `@Published var undoStack: [CanvasAction]`
   - `@Published var sceneState: SceneState`
   - Conexion a Scene3D y RenderManager
3. **Verificar imports**: ContentView.swift necesita importar Core/UI/ViewModels/CanvasViewModel
4. **swift build** -- iterar hasta que pase

### FASE 2: FUNCIONALIDAD MINIMA (3-5 dias)
**Objetivo: La app abre en simulador y muestra un modelo 3D**

1. **Cablear SatinRenderer + Scene3D** a ContentView (SatinView ya existe)
2. **Activar 1 modo** funcional completo (recomendado: Scene3D + camara orbit con gestos)
3. **Conectar undo/redo** motor existente -> UI (botones en toolbar)
4. **Probar en simulador**: que cargue un modelo default y se pueda rotar/zoom

### FASE 3: UX + POTENCIA (1-2 semanas)
**Objetivo: Sentirse mejor que Shapr3D + escultura + paint**

1. **Gestos multi-touch**: pan para orbitar, pinch para zoom, dos dedos para pan
2. **Snapping magnetico**: puntos de snap en sketch CAD, planos de referencia
3. **Onboarding**: overlay tutorial de 3 pasos al primer launch
4. **Feedback haptico**: UIImpactFeedbackGenerator en acciones clave
5. **Menus contextuales**: long-press -> duplicar, eliminar, transformar
6. **Performance**: SDF preview en tiempo real, LOD para mallas grandes
7. **Exportacion**: STL + OBJ + STEP funcionales con progress bar

---

## 4. COMPARATIVA vs COMPETENCIA

| Feature | Shapr3D | Nomad | AppForge (actual) | AppForge (potencial) |
|---------|---------|-------|-------------------|---------------------|
| CAD parametrico | Si | No | Si (12 ops) | Si + snapping |
| Escultura | No | Si | Si (8 deformers) | Si + DynTopo |
| Paint 3D PBR | No | No | Si (pipeline Metal) | Si (layers) |
| Animacion | No | No | Si (keyframe) | Si + easing |
| Export STEP | Si ($299/yr) | No | Si (OCCTSwift) | Si (gratis) |
| iPad nativo | Si | Si | Si (SwiftUI+Metal) | Si |
| Precio | $299/yr | $14.99 | FREE | Freemium |

**Ventaja diferencial de AppForge**: Es el UNICO que combina CAD + escultura + paint 3D + animacion en una sola app. Shapr3D no tiene escultura ni paint. Nomad no tiene CAD. Ninguno tiene animacion.

---

## 5. PROXIMOS PASOS INMEDIATOS

1. Mover backup_sources/AppForgeStudio/ -> Sources/AppForgeStudio/ (manteniendo lo que ya existe)
2. Leer ContentView.swift (Core/UI/) para ver exactamente que propiedades/methods necesita CanvasViewModel
3. Crear CanvasViewModel.swift basado en esos requirements
4. swift build
5. Probar en simulador

Tiempo estimado a app funcional: **5-7 dias** de trabajo enfocado.
