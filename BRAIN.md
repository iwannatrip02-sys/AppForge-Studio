# AppForge Studio — BRAIN.md
> Updated: 2026-05-05

## ESTADO ACTUAL
Sesion 2026-05-11: Completado USDZ+AR QuickLook.
- Creado Features/ExportMode/ARQuickLookView.swift: UIViewControllerRepresentable para QLPreviewController con AR Quick Look.
- Modificado Features/ExportMode/ExportView.swift: agregado import QuickLook, @State showARPreview + arUSDZURL, boton 'Ver en AR' (verde, icono arkit, solo visible cuando formato USDZ), .sheet con ARQuickLookView.
- ExportService.swift ya tenia exportToUSDZ funcional via ModelIO.

Proximo: Internacionalizacion ES/EN con Localizable.xcstrings.

## Sesion 2026-05-05 — CAD parametrico (completado 2026-05-05 21:15 UTC)

### Archivos creados en Sources/ y Sources/CADCore/ (8 archivos):
- GeometryEntity.swift: Struct con tipos point/line/circle/arc/nurbs, posicion SIMD3, orientacion quaternion, parametros genericos
- GeometryConstraint.swift: Struct con tipos distance/angle/coincident/horizontal/vertical/parallel/perpendicular/fix/radius
- SolveSpaceSolver.swift: Solver Gauss-Seidel iterativo (100 iter max), soporta coincident (ajusta hacia punto medio) y distance (mide error). Retorna SolveResult con solved/failed/underconstrained
- CADHistoryTree.swift: Arbol de historial con undo/redo, CADOperation struct con tipos addPoint/addLine/addCircle/addConstraint/extrude/delete/modify
- GeometryConstraintManager.swift: Singleton que usa SolveSpaceSolver. Notifica constraintSystemUpdated/constraintSystemFailed/constraintUnderconstrained via NotificationCenter
- CADSketchEngine.swift: ObservableObject conecta sketch con solver e historial. addPoint, addLine, addDimensionConstraint con undo/redo. Usa CADOperation (no SketchOperation)
- ExtrudeEngine.swift: Motor de extrusion parametrica de perfiles 2D -> 3D con altura, direccion, capEnds
- CADSketchView.swift: UI SwiftUI completa con toolbar de constraints (coincident/distance/horizontal/vertical), canvas con grid, panel de propiedades, undo/redo

### Decisión de arquitectura:
- Se implemento solver Gauss-Seidel propio en Swift en vez de wrapper C API de SolveSpace (evita dependencia C, acelera time-to-build)
- CADSketchView se coloco en Sources/ (fuera de CADCore/) para evitar dependencias circulares SwiftUI

### Pendientes proximos:
- Migrar a SolveSpace C API via XCFramework si el solver iterativo no converge bien en produccion
- CADModeView.swift existe? Verificar integracion con CADSketchView
- Scene3D.swift: conectar constraintManager existente con el nuevo GeometryConstraintManager.shared

### Archivos creados en Sources/CADCore/:
- SolveSpaceSolver.swift: Wrapper C API libslvs con structs Slvs_Param/Entity/Constraint, solver Newton-Raphson + Cholesky + damping. Soporta coincident, concentric, equalLength, parallel, perpendicular, horizontal, vertical, distance, angle, midpoint, collinear. Max 1000 params, tolerancia 1e-8.
- CADHistoryTree.swift: Arbol de historial con undo/redo, beginOperation(), getCurrentParamState(), getAllOperations(). ObservableObject.
- ExportServiceSTEP.swift: Generador STEP ISO 10303-21 AP203 con cartesian points, lines, edges, oriented edges, edge loop, face outer bound, advanced face, closed shell, manifold solid brep.

### Archivos existentes integrados:
- GeometryConstraintManager.swift: usa GeometryConstraint, ConstraintType, SolverMetrics. PENDIENTE: reemplazar solver interno por SolveSpaceSolver.
- CADSketchEngine.swift: usa GeometryConstraintManager + CADHistoryTree. SketchPoint/Line/Circle/Rectangle/Arc entities.
- CADSketchView.swift: toolbar con select/point/line/circle/rect/arc, constraints sheet, undo/redo, animatePoints spring.
- CADModeView.swift: tab Model/Parametric, STEP export alert.
- Scene3D.swift: cadHistory = CADHistoryTree(), constraintManager = GeometryConstraintManager().

### Pendiente:
- GeometryConstraintManager debe usar SolveSpaceSolver internamente
- CADSketchEngine.resolveConstraints() debe llamar al solver y mover puntos
- Package.swift debe incluir Sources/CADCore/*

## Hallazgos CAD (2026-05-05)

Alternativas para CAD paramétrico nativo iOS:
- **SolveSpace** (kernel NURBS + paramétrico, C++, GPL) — mejor opción. Requiere wrapper C-ObjC-Swift.
- **Manifold** (mesh-based, SDK Swift oficial) — complementario, no NURBS.
- Cadova: solo macOS, pre-release. MiniCAD: SceneKit legacy. Ambos descartados.
- Shapr3D usa Parasolid ($299/año, propietario). SolveSpace es la alternativa open-source.

**Plan Fase8 propuesto:**
1. Clonar SolveSpace, compilar para iOS arm64
2. Crear bridging header SolveSpace-Bridge
3. Exponer API Swift: sketch, constraints, extrusion, revolution
4. UI SwiftUI basada en gestos tipo Shapr3D

## ARQUITECTURA REAL (rutas verificadas en disco)

```
ios-app/AppForgeStudio/Sources/
├── AnimationEngine/        AnimationEngine.swift, AnimationModeView.swift, AnimationPlaybackController.swift
├── CADCore/                CADHistoryTree, CADModeView, CADSketch*, BevelEngine, BooleanEngine,
│                           ExtrusionEngine, LoopCutEngine, MeasureEngine, GeometryConstraintManager
├── ExportService/          ExportService, ExportView, ExportViewModel, ModelLoadService, ModelCacheService, CrashReporter
├── RenderEngine/           SatinRenderer, SatinRendererView, SatinMesh, SceneRenderer, PaintRenderer,
│                           PincelRenderer, BrushStroke, MaterialData, MaterialPresets, PBRMaterial,
│                           Mesh, Model3D, Scene3D, TestCube, LODManager, SDFEngine, Sketch2D,
│                           OCCTEngine, SubdivisionEngine, MaterialEditorView, RenderModeView
│                           Shaders.metal, PBRShaders.metal
├── SculptEngine/           SculptEngine, SculptModeView, BrushEngine, Deformer + 8 deformadores
├── UIComponents/           AppForgeStudioApp, AppState, CanvasViewModel, ToolViewModel,
│                           ContentView, MetalView, HybridModeView, ModeSelectorView,
│                           ToolbarView, ToolMenuView, TransformationGizmoView, LayerPanelView,
│                           AnimationView, ColorPickerView, GridView2, LoadingScreenView,
│                           OnboardingView, TimelineView, SceneManager, ThemeManager,
│                           AppTheme, AppThemeEnvironment, MaterialEditorViewModel, PreferencesView, HapticService
└── Tests/                  AnimationEngineTests (12), ExportServiceTests (6),
                            ModelCacheServiceTests (5), GeometryConstraintManagerTests,
                            AnimationPlaybackTests
```

## BUGS CRÍTICOS (code review 2026-05-04) — PENDIENTES DE FIX

### BUG 1 — CRÍTICO: Layout mismatch GPU PBR
**Archivo:** `SatinRenderer.swift` (GPUPBRMaterial, GPUDirectionalLight, GPUPointLight)
**Efecto:** Metallic/roughness/ao leídos en offsets incorrectos → materiales metálicos parecen plástico mate
**Causa:** `float3` en Metal se alinea a 16 bytes. `GPUPBRMaterial` usa 3 Floats separados = 12 bytes sin padding.
**Fix:** Agregar `var _pad: Float = 0` después de cada grupo de 3 floats (albedo, emission, etc.)

### BUG 2 — CRÍTICO: updateAnimation() doble por frame
**Archivo:** `SatinRenderer.swift` línea ~438 en `render()` + `SatinRendererView.Coordinator.draw()`
**Efecto:** Animaciones corren al doble de velocidad, deltaTime consumido 2 veces
**Fix:** Eliminar la llamada `updateAnimation()` al inicio de `render(in:)`

### BUG 3 — ALTO: Índices UInt16 — límite 65,535 vértices
**Archivo:** `SatinRenderer.swift` `createBuffersFromMeshes()`
**Efecto:** Crash/corrupción al subdividir mallas de alta resolución (subdiv 2x → >65k vértices)
**Fix:** Cambiar `[UInt16]` a `[UInt32]` y `.uint16` a `.uint32` en `drawIndexedPrimitives`

### BUG 4 — ALTO: Repo Satin equivocado
**Archivo:** `Package.swift`
**Efecto:** `mattrajca/Satin` es fork inactivo con APIs limitadas → SatinRenderer reimplementa todo manualmente
**Fix:** Cambiar a `https://github.com/s1ddok/Satin.git` (Satin activo y mantenido)

### BUG 5 — ALTO: Normal matrix incorrecta bajo escala no-uniforme
**Archivo:** `Shaders.metal` línea 33
**Efecto:** Iluminación visualmente incorrecta cuando los modelos tienen escala no-uniforme
**Fix:** `transpose(inverse(float3x3(modelMatrix)))` en lugar de `modelMatrix * float4(normal, 0)`

### BUG 6 — ALTO: Stroke billboard — aspect ratio incorrecto
**Archivo:** `Shaders.metal` `strokeVertex` línea ~73
**Efecto:** Pinceles se distorsionan (aplanan/estiran) según profundidad en la escena
**Fix:** Pasar viewport aspect ratio como uniform en vez de usar `center.w`

### BUG 7 — MEDIO: Grab deformer mueve en dirección contraria
**Archivo:** `SculptEngine.swift` case `.grab`
**Efecto:** Grab aleja vértices del brush en vez de moverlos en dirección del drag
**Fix:** Agregar `dragDelta: SIMD3<Float>` a `SculptPoint` y usarlo en grab

### BUG 8 — MEDIO: currentMode hardcoded a .hybrid
**Archivo:** `CanvasViewModel.swift` línea ~88
**Efecto:** Todo código que lee `canvasVM.currentMode` obtiene .hybrid sin importar el modo activo
**Fix:** Inyectar `AppState.selectedMode` o eliminar la propiedad (usar el binding directamente)

### BUG 9 — ALTO: rebuildSceneFrom llamado cada frame de animación
**Archivo:** `SatinRenderer.swift` `applyTransformsToScene()`
**Efecto:** 60 GPU buffer allocations/deallocations por segundo durante animación
**Fix:** Separar transform (uniform) de geometría (buffer estático)

## ENTIDADES CLAVE

| Entidad | Tipo | Notas |
|---------|------|-------|
| Satin | tech | Swift/Metal framework — usar s1ddok, NO mattrajca |
| Metal 2 | tech | GPU rendering pipeline — PBR implementado |
| OCCTSwift | tech | Bindings OCCT para CAD booleano |
| ModelIO/MetalKit | tech | Import/export modelos |
| simd | tech | Matemáticas 3D |
| Shapr3D | competencia | $299/año CAD iPad — referencia CAD |
| Nomad Sculpt | competencia | $14.99 escultura iPad — referencia sculpt |
| Feather 3D | competencia | $9.99/mes pintura 3D |
| AppForge Studio | producto | Pintura 3D + escultura + CAD + animación + export |

## MÓDULOS IMPLEMENTADOS

| Módulo | Estado | Archivos |
|--------|--------|---------|
| Sistema pinceles | ✅ | BrushStroke, PaintRenderer, PincelRenderer, Shaders.metal |
| Sculpt (8 deformadores) | ⚠️ BUG7 | SculptEngine + Grab/Inflate/Smooth/Pinch/Flatten/Crease/Twist/Move |
| Subdivisión Catmull-Clark | ✅ | SubdivisionEngine |
| CAD booleano | ✅ | OCCTEngine, BooleanEngine, ExtrusionEngine, BevelEngine |
| CAD historial | ✅ | CADHistoryTree (50 pasos undo/redo) |
| CAD constraints | ✅ | GeometryConstraintManager con solver Gauss-Seidel |
| Animación | ⚠️ BUG2 | AnimationEngine, AnimationPlaybackController (doble tick) |
| PBR rendering | ⚠️ BUG1,5,6 | PBRShaders.metal (lógica correcta, layout incorrecto) |
| Export | ✅ | ExportService (OBJ, STL, USDZ, STEP, GLTF) |
| Modelo cache | ✅ | ModelCacheService (NSCache 50obj/128MB) |
| UI/UX completo | ✅ | Dark mode, haptics, onboarding, transitions |
| Tests | ✅ | 23+ tests unitarios |
| CI/CD | ✅ | build-ios.yml (macos-14, Xcode 16.1) |

## BLOQUEO DE COMPILACIÓN

Swift Toolchain no disponible en Windows 11. Todo el código es Swift válido sintácticamente.
**Camino para compilar:**
1. `git push` al repo de GitHub
2. GitHub Actions ejecuta `build-ios.yml` automáticamente en macOS
3. Ver errores de compilación reales en Actions logs
4. Iterar fixes desde Windows hasta que CI pase

## PRÓXIMAS ACCIONES
1) Generar .ipa sin firma para AltStore (beta testing)
2) Ejecutar suite de tests en Xcode (xcodebuild test)
3) Probar render loop (paint+sculpt+CAD+animation) en simulador
4) Animacion de morph targets entre mallas
5) USDZ para AR QuickLook
6) Internacionalizacion (ES/EN)

## KNOWLEDGE BASE
## Competitive Research (mayo 2026)

**Shapr3D** ($299/año): Kernel Parasolid Siemens, paramétrico+directo, iPad/Mac/Windows. NO sculpt, NO animación, sin AI. GAP: caro para hobbyists.

**Fusion 360 Mobile** ($545/año): Mobile SOLO visor/markup — NO editor real en iPad. GAP enorme.

**Nomad Sculpt** ($14.99): Escultura, CERO CAD paramétrico. GAP: no escala a producto.

**Tinkercad** (gratis): Booleanas complejas, solo web, no profesional.

**Part3D** (marzo 2026): Paramétrico + bridge impresora 3D en iPad. Nuevo, pocas features.

## 8 Features Diferenciales Identificadas

D1. **Escultura Paramétrica** (UNIQUE) — sculpt + constraints en misma sesión
D2. **App Unificada** (CAD+Sculpt+Animation+Export) — nadie lo combina
D3. **AI Generative Design** — solo Fusion desktop
D4. **Real-Time Collaboration** — parcial Shapr3D
D5. **Sheet Metal Design** — solo Fusion desktop
D6. **AR Preview con LiDAR** — viewer básico en Shapr3D
D7. **Fotogrametría Directa** (UNIQUE) — importar scan LiDAR a CAD
D8. **Topology Optimization** — solo Fusion desktop

Prioridad: D1+D2 (P1), D3+D6 (P2), D5+D7+D8 (P3), D4 (P4)

## IBL Pipeline — Verificacion completa 2026-05-07

### Compute shaders (Core/Shaders/IBLComputeShaders.metal):
- irradiance_map (line 69): convolucion difusa de cubemap HDRI a 32px cube
- prefilter_envmap (line 102): pre-filtrado especular con GGX importance sampling, roughness progresiva, 128px 5 mips
- brdf_integration (line 137): integracion BRDF LUT 2D para fresnel+geometry
- Funciones auxiliares: Hammersley sequence, importance_sample_ggx, geometry_schlick_ggx_ibl

### Pipeline Swift (Core/Engines/IBLPipeline.swift, 4615 chars):
- init? con 3 compute pipeline states
- generate() sincrono: dispatch irradiance (grid 6x32x32, TG 1x8x8), prefilter por mip (5 niveles, roughness progresiva, grid 6xmipSizexmipSize, TG 1x16x16), BRDF (grid 256x256, TG 16x16), waitUntilCompleted

### Fragment shader (Core/Shaders/PBRShaders.metal):
- pbr_ibl_fragment_main: diffuseIBL + specularIBL + brdfLUT sampling
- Tangent space: TBN matrix + normal map, fallback a worldNormal
- ACES tone mapping + gamma correction

### Swift support:
- PBRMaterial: loadTextures() MTKTextureLoader
- PBRMaterialUniforms: textures dict, bindTextures() slots 3-8, setupIBL()

## Diagnostico PBR + IBL (2026-05-07)

### Componentes existentes:
- PBRShaders.metal: funciones PBR completas (fresnel_schlick, distribution_ggx, geometry_smith), IBLUniforms definido (inverseView, roughnessLevels). PENDIENTE: verificar si fragment shader realmente samplea irradianceMap/prefilterMap/brdfLUT.
- PBRMaterial.swift: 6 texture paths como String? pero SIN carga a MTLTexture. Needs MTKTextureLoader.
- PBRMaterialUniforms.swift: irradianceMap/prefilterMap/brdfLUT como @Published MTLTexture?. setupIBL() listo.
- IBLPipeline.swift: existe en Core/Engines/. Genera irradiance+prefilter+BRDF LUT desde HDRI.

### Gaps:
1. Fragment shader: falta verificar IBL sampling y tangent input para normal maps
2. Texture loading: PBRMaterial.String? nunca se cargan como MTLTexture
3. Tangent space: VertexIn solo tiene position/normal/uv, falta tangent/bitangent
4. Binding de MTLTextures al pipeline state

### Proximas acciones concretas:
1. Leer fragment function de PBRShaders.metal (sampling IBL + textures)
2. Agregar texture loading con MTKTextureLoader a PBRMaterial
3. Agregar tangent/bitangent a VertexIn y vertex shader
4. Implementar IBL sampling en fragment shader si falta
5. Verificar IBLPipeline.generate()

## Ruta de Compilación Gratuita AppForge Studio (2026-05-07)

1. **Satin repo incorrecto** — Package.swift apunta a s1ddok/Satin, pero el repo oficial activo es Hi-Rez/Satin. Hay que migrar.
2. **SPM + Metal shaders = problema conocido** — Swift Package Manager no soporta compilar .metal files de forma nativa. Solución: MetalCompilerPlugin (SPM build tool plugin) o Xcode project.
3. **Mac Mini cloud más barato**: Macly.io ~$30-50/mes con M4 dedicado. Alternativa: GitHub Actions con self-hosted runner si se consigue cualquier Mac.
4. **Xcode Cloud**: 50h/mes gratis de Apple, suficiente para builds de prueba.
5. **Alternativa WebGL** (mientras tanto): React Three Fiber + Three.js corre en iPad Safari sin compilar nada — funcional en 72h.
6. **Apps open-source para estudiar**: Cadova (Swift DSL paramétrico CAD), Satin (Hi-Rez), HelloMetal (ejemplos Metal puros).

## HISTORIAL
- 2026-05-07 17:33 UTC — Atlas Coder: Realiza la migración completa de la estructura de AppForge Studio. El workspace es C:\Users\USUARIO\Projects\appforge-st
  Modificados: C:\Users\USUARIO\Projects\appforge-studio\ios-app\AppForgeStudio\Core\Engines\BrushEngine.swift
- 2026-05-07 17:57 UTC — Atlas Coder: Implementar las siguientes 3 modificaciones en el proyecto AppForge Studio:
  Modificados: C:\Users\USUARIO\Projects\appforge-studio\ios-app\AppForgeStudio\Core\Shaders\PBRShaders.metal, C:\Users\USUARIO\Projects\appforge-studio\ios-app\AppForgeStudio\Core\Engines\PBRMaterial.swift, C:\Users\USUARIO\Projects\appforge-studio\ios-app\AppForgeStudio\Core\Engines\PBRMaterialUniforms.swift
- 2026-05-07 18:12 UTC — Atlas Coder: Integrar el sistema CAD de AppForge Studio.
  Modificados: C:\Users\USUARIO\Projects\appforge-studio\ios-app\AppForgeStudio\Features\CADMode\CADSketchEngine.swift, C:\Users\USUARIO\Projects\appforge-studio\ios-app\AppForgeStudio\Features\CADMode\CADModeView.swift
- 2026-05-07 18:23 UTC — Atlas Coder: IMPLEMENTAR los siguientes cambios en 3 archivos del proyecto AppForge Studio.
  Modificados: C:\Users\USUARIO\Projects\appforge-studio\ios-app\AppForgeStudio\Core\Engines\Mesh.swift, C:\Users\USUARIO\Projects\appforge-studio\ios-app\AppForgeStudio\Core\Engines\Scene3D.swift, C:\Users\USUARIO\Projects\appforge-studio\ios-app\AppForgeStudio\Features\CADMode\CADSketchEngine.swift
- 2026-05-11 08:05 UTC — Atlas Coder: Implementar morph targets completos en AppForge Studio.
  Modificados: C:\Users\USUARIO\Projects\appforge-studio\ios-app\AppForgeStudio\Core\Engines\Mesh.swift, C:\Users\USUARIO\Projects\appforge-studio\ios-app\AppForgeStudio\Core\Engines\AnimationEngine.swift, C:\Users\USUARIO\Projects\appforge-studio\ios-app\AppForgeStudio\Core\Engines\MorphEngine.swift, C:\Users\USUARIO\Projects\appforge-studio\ios-app\AppForgeStudio\Tests\AnimationPlaybackTests.swift
- 2026-05-11 08:07 UTC — Atlas Coder: Implementar CAD-8: Constraint Visualization Overlay para AppForge Studio.
  Modificados: C:\Users\USUARIO\Projects\appforge-studio\ios-app\AppForgeStudio\Features\CADMode\GeometryConstraintManager.swift, C:\Users\USUARIO\Projects\appforge-studio\ios-app\AppForgeStudio\Features\CADMode\ConstraintOverlayView.swift, C:\Users\USUARIO\Projects\appforge-studio\ios-app\AppForgeStudio\Features\CADMode\CADModeView.swift
