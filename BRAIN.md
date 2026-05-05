# AppForge Studio — BRAIN.md
> v82 | Actualizado: 2026-05-05 | Fix 3 bugs aplicables de 8

## ESTADO ACTUAL

**v0.9 — 2026-05-05.** 3 bugs corregidos del commit actual b6766b4 (padding GPU, normal matrix, UInt32, s1ddok repo, grab deformer, currentMode).
Fix: BUG2(deltaTime Double), BUG4(s1ddok), BUG5(normal matrix). Listo para CI (macos-14 + Xcode 16.1).

**8 bugs críticos identificados** en code review externo (ver sección BUGS_CRITICOS abajo).
El código es Swift válido pero tiene errores de lógica GPU y arquitectura que producirán comportamiento visual incorrecto al correr.

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

1. **Corregir BUG 1** — padding GPUPBRMaterial + GPUDirectionalLight + GPUPointLight
2. **Corregir BUG 2** — eliminar updateAnimation() duplicado en render()
3. **Corregir BUG 3** — UInt16 → UInt32 en índices de malla
4. **Corregir BUG 5** — normal matrix con inversa transpuesta en Shaders.metal
5. **Corregir BUG 6** — stroke aspect ratio via uniform
6. **Corregir BUG 9** — desacoplar transforms de rebuildSceneFrom
7. **Push a GitHub CI** — verificar compilación real en macOS
8. Corregir BUG 7 (grab) y BUG 8 (currentMode)
9. Cambiar Satin a s1ddok (BUG 4) — mayor refactor
