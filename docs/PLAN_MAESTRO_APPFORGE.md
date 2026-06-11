# PLAN MAESTRO — AppForge Studio
> Generado: 2026-06-10 | Auditoría verificada contra código fuente real (520 .swift, 210 .metal)
> Repo: https://github.com/iwannatrip02-sys/AppForge-Studio.git (branch: main)

## 0. Estado Verificado (2026-06-10)

### 0.1 Evidencia de git

**Últimos 15 commits** (todos CI-focused, 2026-05-26):
```
90b53c5 ci: remove -arch arm64 (conflicts with destination), sed patch handles narrowing errors
1d83151 ci: patch SatinCore Triangulator.mm narrowing errors with sed before build, -arch arm64
700836b build: add -Wno-c++11-narrowing to suppress SatinCore C++ errors on x86_64, disable warnings-as-errors
e36c62b build: EXCLUDED_ARCHS x86_64 (OCCTSwift arm64 only, SatinCore C++ narrowing), ONLY_ACTIVE_ARCH YES, disable narrowing warnings
0e5662c ci: install iOS simulator runtime before build, use generic iOS Simulator destination + iphonesimulator SDK
d4614e2 ci: build for iOS Simulator (iPad Pro M4), device SDK not on runner, log always
614569c ci: macos-15 runner, auto-detect Swift 6.1+ across all Xcodes, fallback download swift.org
00af3f1 fix: swift-tools-version 6.0→6.1 (OCCTSwift requires 6.1.0)
8a45b53 ci: detect and select Xcode 16.x with Swift 6.x, iterate available Xcodes
0906898 ci: add Info.plist as real file (fixes YAML heredoc parse error)
fc6b2cc ci: fix YAML parse error — Info.plist as real file (not inline heredoc), remove preBuildScript
a124165 ci: fix Xcode path (16.0.app not found), use default xcode-select, list available Xcodes
1dbda83 ci: fix OCCTSwift in project.yml, add build log artifact, tee build output
030c7a9 ci: fix workflow location (root .github/workflows/), add working-directory, OCCTSwift dependency resolution
e1e14a6 v2.0-cad-engine: SelectionManager, DirectModelingEngine, OCCTConstraintSolver, ProjectPersistence, ProfessionalExportEngine, PatternEngine, MirrorEngine, ThreadEngine, DraftEngine
```

**Working tree (git status --short):**
```
 M ios-app/AppForgeStudio/BRAIN.md
 M ios-app/AppForgeStudio/TODO.md
?? Hi-Rez-Satin/                          ← clon local del framework Satin (~350 archivos, untracked)
?? docs/analisis-code-review.md
?? docs/fases-desarrollo.md
?? docs/plan-maestro-ejecucion.md
?? ios-app/AppForgeStudio/docs/bugfix-sesion.md
?? ios-app/AppForgeStudio/docs/mejoras-gotchi-mayo-2026.md
?? nul                                    ← archivo basura de Windows, debe eliminarse
```

**Remote:** `origin https://github.com/iwannatrip02-sys/AppForge-Studio.git`

### 0.2 Conteo de archivos

| Tipo | Cantidad | Evidencia |
|------|----------|-----------|
| `.swift` | 520 | `Get-ChildItem -Recurse -Filter *.swift` en raíz del repo |
| `.metal` | 210 | `Get-ChildItem -Recurse -Filter *.metal` en raíz del repo |
| Tests `.swift` | 7 archivos | Glob `**/Tests/**/*.swift` en ios-app/AppForgeStudio |
| Funciones de test | ~60 | `grep -c "func test"` sobre los 7 archivos |

### 0.3 CI — GitHub Actions (build.yml)

**Lo que SÍ hace:**
1. Checkout + seleccionar Xcode 16+ con Swift 6.1+
2. Instalar XcodeGen + generar `.xcodeproj`
3. Resolver dependencias SPM (Satin 13.0.0 + OCCTSwift 1.0.0)
4. **Parchar SatinCore** — `sed` sobre `Triangulator.mm` para corregir narrowing errors (`static_cast<uint32_t>`)
5. Instalar iOS Simulator runtime
6. **`xcodebuild build`** (solo build, NO test) para iOS Simulator, sin code signing
7. Subir build.log como artifact

**Lo que NO hace (gap crítico):**
- **NO ejecuta tests** — no hay paso `xcodebuild test`. El target de tests existe en `project.yml` pero no se invoca.
- NO genera `.ipa` ni archive
- NO hace análisis estático ni linting

**Últimos 5 runs (gh run list):**
```
✓ 26446439823  main  ci: remove -arch arm64...              4m23s  success  2026-05-26
✓ 26445405733  main  ci: patch SatinCore Triangulator...     8m18s  success  2026-05-26
✓ 26444735380  main  build: add -Wno-c++11-narrowing...     10m31s  success  2026-05-26
✓ 26444292911  main  build: EXCLUDED_ARCHS x86_64...         5m28s  success  2026-05-26
✓ 26443811459  main  ci: install iOS simulator runtime...    7m15s  success  2026-05-26
```
Todos verde. Build pasa. Tests NO ejecutados.

### 0.4 Bugs pendientes — verificación línea por línea

| Bug ID | Archivo | Línea(s) | Severidad | Estado real | Evidencia |
|--------|---------|----------|-----------|-------------|-----------|
| **BUG1** | `Sources/Engines/SatinRenderer.swift` | 27-34 | CRÍTICO | **CONFIRMADO** | `GPUPBRMaterial` de Swift tiene `emissionR` en offset 28, pero Metal espera `float3 emission` en offset 32 (alineación 16 bytes). Faltan 4 bytes de padding entre `ao` y `emissionR`. El shader `PBRShaders.metal:29-35` define `PBRMaterialUniforms` con `float3 emission` que requiere alineación 16. |
| **BUG2** | `Sources/Engines/SatinRenderer.swift` | 88-149, 724-738 | CRÍTICO | **CONFIRMADO** | `updateAnimation()` (→`applyTransformsToScene()` línea 147) llama `rebuildSceneFrom()`. `render(in:)` (línea 736) también llama `rebuildSceneFrom()` si hay sculpt. En un frame con animación + sculpt = doble rebuild. |
| **BUG3** | `Sources/Engines/SatinRenderer.swift` + `Mesh.swift` | — | ALTO | **YA CORREGIDO** | `Mesh.indices` es `[UInt32]` (Mesh.swift:35). `createBuffersFromMeshes` usa `[UInt32]` (línea 597), stride `UInt32` (617), draw call `.uint32` (828). |
| **BUG5** | `Sources/Shaders/Shaders.metal` | 33 | ALTO | **CONFIRMADO** | Normal matrix `transpose(inverse(float3x3(uniforms.modelMatrix)))` calculada por vértice en GPU. Correcto matemáticamente pero muy caro (inverse+transpose por vertex). Debe pre-calcularse en CPU por modelo y pasarse como uniform. Mismo patrón en `PBRShaders.metal:187` e `IBLShaders.metal:181`. |
| **BUG7** | `Sources/Engines/SculptEngine.swift` | 93-95 | MEDIO | **CONFIRMADO** | Grab deformer: `let displacement = point.position - vertex.position` mueve vértices hacia el centro del pincel, ignorando `point.dragDelta`. Debería usar `point.dragDelta` para mover en dirección del arrastre. |
| **BUG9** | `Sources/Engines/SatinRenderer.swift` | 147, 545-593, 736 | ALTO | **CONFIRMADO** | `rebuildSceneFrom()` se llama cada frame durante animación (línea 147) y durante sculpt (línea 736). Reconstruye todo el scene graph: nuevos Objects, buffers, `pbrRenderables`. ~60 allocs/seg innecesarias. Debe actualizar transforms in-place en los objetos Satin existentes. |

**Resumen bugs: 5 confirmados activos (BUG3 ya corregido).**

### 0.5 Dependencias críticas

| Dependencia | Versión | Estado | Riesgo |
|-------------|---------|--------|--------|
| Hi-Rez/Satin | 13.0.0 (from:) | **ARCHIVADO** (15 Abr 2025) | ALTO — sin mantenimiento, sin fixes de seguridad |
| gsdali/OCCTSwift | 1.0.0 (from:) | Activo | MEDIO — xcframework pre-compilado iOS arm64 (~190 MB) |
| Swift Tools | 6.1 | OK | — |

**Satin archivado**: https://github.com/Hi-Rez/Satin — "This repository was archived by the owner on Apr 15, 2025. It is now read-only." 851 stars, 74 forks, MIT license. Último tag: 13.0.0.

### 0.6 Hi-Rez-Satin/ untracked

Directorio `Hi-Rez-Satin/` en raíz del repo (~350 archivos, untracked). Es un clon completo del framework Satin, presumiblemente para vendorización futura. **No está integrado en Package.swift ni en el build.** Debe decidirse: vendorizarlo oficialmente o eliminarlo.

### 0.7 Archivos huérfanos

- `nul` en raíz — artefacto de Windows (`> nul` en vez de `> /dev/null`). Debe eliminarse.
- `ios-app/AppForgeStudio/docs/ARCHITECTURE.md` — listado en Glob pero no existe en disco (error 404 al leer).

---

## 1. Visión y Criterio de Éxito

### 1.1 Visión
AppForge Studio será la **primera aplicación iOS nativa gratuita y open-source** que unifica pintura 3D + escultura digital + CAD paramétrico + animación + exportación profesional en un solo producto, superando a:

| Competidor | Precio | Fortalezas | Debilidades |
|------------|--------|------------|-------------|
| Shapr3D | $299/año | CAD paramétrico, Siemens Parasolid | Sin escultura, sin pintura 3D |
| Nomad Sculpt | $15 (one-time) | Escultura digital excelente | Sin CAD, sin animación |
| Feather3D | Free | Ligero, open-source | Solo escultura básica |
| Fusion 360 | $680/año | CAD profesional completo | No iOS nativo, no escultura |

**Propuesta de valor:** AppForge = Shapr3D + Nomad Sculpt + Blender → 1 app gratis.

### 1.2 Criterio de éxito medible (MVP gate)

1. **Build verde** en CI (GitHub Actions macOS runner) con **≥60 tests pasando** (todos los existentes + nuevos de regresión)
2. **App funcional** en iOS Simulator con los 4 modos (CAD, Sculpt, Hybrid, Export) renderizando sin crashes
3. **Escultura táctil**: deformers responden a input táctil con <16ms latencia (60fps)
4. **CAD funcional**: al menos 3 operaciones booleanas (union, difference, intersection) verificadas con tests
5. **Exportación**: OBJ + STL producen archivos válidos (verificables con cualquier visor 3D)
6. **Animación**: keyframe interpolation funcional con ≥2 modelos animándose simultáneamente a 60fps
7. **Release gratuito**: `.ipa` unsigned generado en CI, instalable vía AltStore/Sideloadly en iPad físico

---

## 2. Fases

### FASE 0 — CI Verde + Corrección de Bugs Críticos (Duración: 3-5 días)

**Objetivo:** CI build + tests verde, bugs críticos corregidos.
**Gate de salida:** `gh run watch` muestra ✅ verde con `xcodebuild test` pasando 60/60 tests.

#### F0.T1 — Agregar paso `xcodebuild test` al CI
- **Archivos a leer:** `.github/workflows/build.yml` (líneas 93-113)
- **Archivos a editar:** `.github/workflows/build.yml`
- **Qué hacer:** Agregar un paso después de "Build for iOS" que ejecute `xcodebuild test -project AppForgeStudio.xcodeproj -scheme AppForgeStudio -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M4)' -configuration Debug CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO 2>&1 | tee test.log`. También agregar upload del test log como artifact.
- **Qué NO tocar:** No modificar el paso de build existente, no cambiar scheme, no tocar project.yml.
- **Verificación:** Push a branch `f0/ci-add-tests` → `gh run watch` → verificar que el paso `test` aparece y se ejecuta.
- **Criterio de aceptación:** El workflow tiene un paso `xcodebuild test` que se ejecuta. Si hay test failures, se reportan en el log.
- **Complejidad:** S | Paralelizable: No (depende de F0 completado)

#### F0.T2 — Fix BUG1: float3 padding en GPUPBRMaterial
- **Archivos a leer:** `ios-app/AppForgeStudio/Sources/Engines/SatinRenderer.swift:27-34`, `ios-app/AppForgeStudio/Sources/Shaders/PBRShaders.metal:28-35`
- **Archivos a editar:** `ios-app/AppForgeStudio/Sources/Engines/SatinRenderer.swift`
- **Qué hacer:** Insertar `var _padEmissionAlign: Float = 0` entre `var ao: Float` y `var emissionR: Float` en `struct GPUPBRMaterial`. La nueva estructura debe ser: `albedoR, albedoG, albedoB, _pad1` (16B) → `metallic, roughness, ao, _padEmissionAlign` (16B) → `emissionR, emissionG, emissionB, _pad2` (16B) → `emissionIntensity` (4B). Esto alinea `emission` a offset 32 como espera Metal para `float3`.
- **Qué NO tocar:** No modificar PBRShaders.metal ni otras structs GPU (FrameUniforms, BasicUniforms, etc.)
- **Verificación:** Push a branch `f0/fix-bug1-float3-padding` → CI build pasa → diff muestra exactamente 1 línea agregada en SatinRenderer.swift.
- **Criterio de aceptación:** Build verde + PBR rendering no muestra corrupción visual de materiales (verificable solo con screenshots del simulador).
- **Complejidad:** S | Paralelizable: Sí (con F0.T3, F0.T5)

#### F0.T3 — Fix BUG2: updateAnimation doble rebuild por frame
- **Archivos a leer:** `ios-app/AppForgeStudio/Sources/Engines/SatinRenderer.swift:88-149, 537-543, 724-738`
- **Archivos a editar:** `ios-app/AppForgeStudio/Sources/Engines/SatinRenderer.swift`
- **Qué hacer:** Agregar una flag `private var needsSceneRebuild = false`. En `applyTransformsToScene()` (línea 145-148), en vez de llamar `rebuildSceneFrom()` directamente, setear `needsSceneRebuild = true` y actualizar transforms in-place sobre los objetos Satin existentes. En `render(in:)` (línea 734-737), mismo patrón: setear flag en vez de rebuild inmediato. Agregar al final de `render(in:)` (antes de `encoder.endEncoding()`): si `needsSceneRebuild == true`, llamar `rebuildSceneFrom()` UNA sola vez y resetear flag.
- **Qué NO tocar:** No modificar `createBuffersFromMeshes`, `buildObject`, ni los shaders.
- **Verificación:** Push a branch `f0/fix-bug2-double-rebuild` → CI build pasa.
- **Criterio de aceptación:** `rebuildSceneFrom` se llama ≤1 vez por frame (verificable con profiling o contador interno).
- **Complejidad:** M | Paralelizable: Sí (con F0.T2)

#### F0.T4 — Fix BUG3: YA CORREGIDO — Verificar y documentar
- **Archivos a leer:** `ios-app/AppForgeStudio/Sources/Engines/Mesh.swift:35`, `ios-app/AppForgeStudio/Sources/Engines/SatinRenderer.swift:597,617,828`
- **Archivos a editar:** `ios-app/AppForgeStudio/BRAIN.md` (mover BUG3 a "Corregidos")
- **Qué hacer:** Verificar que `Mesh.indices` es `[UInt32]`, que `createBuffersFromMeshes` usa `UInt32` en todas partes, que `indexType: .uint32`. Confirmar y mover BUG3 a la tabla de bugs corregidos en BRAIN.md. Agregar un test que verifique que mallas de >65535 vértices se crean correctamente (opcional, nice-to-have).
- **Qué NO tocar:** No cambiar tipos de índice (ya están correctos).
- **Verificación:** `grep -n "UInt16" ios-app/AppForgeStudio/Sources/Engines/SatinRenderer.swift` debe devolver 0 resultados.
- **Criterio de aceptación:** Cero referencias a UInt16 en la ruta de índices.
- **Complejidad:** S | Paralelizable: Sí

#### F0.T5 — Fix BUG5: Normal matrix pre-computada en CPU
- **Archivos a leer:** `ios-app/AppForgeStudio/Sources/Shaders/Shaders.metal:29-38`, `ios-app/AppForgeStudio/Sources/Shaders/PBRShaders.metal:180-194`, `ios-app/AppForgeStudio/Sources/Engines/SatinRenderer.swift:806-831`
- **Archivos a editar:** `ios-app/AppForgeStudio/Sources/Shaders/Shaders.metal`, `ios-app/AppForgeStudio/Sources/Shaders/PBRShaders.metal`, `ios-app/AppForgeStudio/Sources/Shaders/IBLShaders.metal`, `ios-app/AppForgeStudio/Sources/Engines/SatinRenderer.swift`
- **Qué hacer:**
  1. Agregar `var normalMatrix: simd_float3x3` a `FrameUniforms` (SatinRenderer.swift:10-15).
  2. En el loop de render PBR (línea 806-831), calcular `normalMatrix` UNA vez por modelo: `let normalMatrix = simd_float3x3(...).inverse.transpose` y asignarlo a `frameUniforms.normalMatrix`.
  3. En los 3 vertex shaders (.metal), reemplazar `transpose(inverse(float3x3(uniforms.modelMatrix)))` por `uniforms.normalMatrix`.
- **Qué NO tocar:** No modificar los fragment shaders, no cambiar la estructura de uniforms existentes.
- **Verificación:** Push a branch `f0/fix-bug5-normal-matrix` → CI build pasa.
- **Criterio de aceptación:** `grep -r "transpose(inverse" ios-app/AppForgeStudio/Sources/Shaders/` devuelve 0 resultados.
- **Complejidad:** M | Paralelizable: Sí (con F0.T2)

#### F0.T6 — Fix BUG7: Grab deformer usa dragDelta
- **Archivos a leer:** `ios-app/AppForgeStudio/Sources/Engines/SculptEngine.swift:93-95`, `ios-app/AppForgeStudio/Sources/Engines/SculptEngine.swift:6-11` (SculptPoint)
- **Archivos a editar:** `ios-app/AppForgeStudio/Sources/Engines/SculptEngine.swift`
- **Qué hacer:** Cambiar línea 94 de `let displacement = point.position - vertex.position` a `let displacement = point.dragDelta`. Si `dragDelta` es cero (primer toque), mantener comportamiento actual como fallback: `let displacement = simd_length(point.dragDelta) > 0.001 ? point.dragDelta : (point.position - vertex.position)`.
- **Qué NO tocar:** No modificar otros deformers, no cambiar la firma de SculptPoint.
- **Verificación:** Push a branch `f0/fix-bug7-grab-delta` → CI build pasa.
- **Criterio de aceptación:** Línea 94 de SculptEngine.swift referencia `point.dragDelta`.
- **Complejidad:** S | Paralelizable: Sí

#### F0.T7 — Fix BUG9: rebuildSceneFrom solo cuando necesario
- **Archivos a leer:** `ios-app/AppForgeStudio/Sources/Engines/SatinRenderer.swift:117-149, 537-543, 545-593, 724-738`
- **Archivos a editar:** `ios-app/AppForgeStudio/Sources/Engines/SatinRenderer.swift`
- **Qué hacer:**
  1. En `applyTransformsToScene()`, en vez de llamar `rebuildSceneFrom()`, actualizar las propiedades `position`, `rotation`, `scale` directamente en los `Object`s de Satin ya existentes en `self.scene`. Mantener un diccionario `[String: Object]` para lookup O(1).
  2. Agregar método `updateTransformsInPlace(_ transforms: [String: simd_float4x4])` que modifica los objetos Satin sin recrearlos.
  3. `rebuildSceneFrom()` solo se llama en `updateScene()` cuando `structureChanged == true`.
  4. En `render(in:)`, el path de sculpt debe modificar los buffers existentes (vía `applySculpt`) sin reconstruir toda la escena.
- **Qué NO tocar:** No modificar `createBuffersFromMeshes` ni `buildObject`.
- **Verificación:** Push a branch `f0/fix-bug9-rebuild-optimization` → CI build pasa.
- **Criterio de aceptación:** `rebuildSceneFrom` no se llama en el path de animación (verificable con `os_log` cada vez que se ejecuta).
- **Complejidad:** L | Paralelizable: No (depende de F0.T3 para evitar conflictos)

---

### FASE 1 — Tests y Cobertura (Duración: 3-5 días)

**Objetivo:** ~60 tests pasando en CI, cobertura básica de los motores core.
**Gate de salida:** `xcodebuild test` reporta ≥60 tests pasados, 0 failures.

#### F1.T1 — Hacer que los tests existentes compilen y pasen
- **Archivos a leer:** Los 7 archivos en `Tests/` + `project.yml`
- **Archivos a editar:** `project.yml` (si faltan configuraciones de test target)
- **Qué hacer:** Ejecutar tests en CI, recopilar failures, corregir imports/API changes uno por uno. Priorizar: primero compilación, luego assertions.
- **Qué NO tocar:** No reescribir tests completos, solo arreglos mínimos.
- **Verificación:** CI test step pasa con ≥50 tests verdes.
- **Criterio de aceptación:** `gh run watch` muestra ✅ en el paso de test.
- **Complejidad:** L | Paralelizable: No

#### F1.T2 — Agregar tests de regresión para los 5 bugs corregidos en F0
- **Archivos a crear:** `Tests/RegressionTests.swift` (nuevo)
- **Archivos a editar:** `project.yml` (agregar RegressionTests.swift al test target si es necesario)
- **Qué hacer:** Escribir 5 tests mínimos:
  1. `testGPUPBRMaterialLayout` — verifica `MemoryLayout<GPUPBRMaterial>.stride` ≥ 52
  2. `testSingleRebuildPerFrame` — mock SatinRenderer, verifica que `rebuildSceneFrom` se llama ≤1 vez
  3. `testMeshIndexTypeIsUInt32` — verifica que `Mesh.indices` es `[UInt32]`
  4. `testNormalMatrixInUniforms` — verifica que FrameUniforms tiene campo `normalMatrix`
  5. `testGrabDeformerUsesDragDelta` — verifica que el código referencia `dragDelta`
- **Qué NO tocar:** No modificar código fuente, solo agregar tests.
- **Verificación:** 5 nuevos tests pasando en CI.
- **Criterio de aceptación:** ≥65 tests totales pasando.
- **Complejidad:** M | Paralelizable: Sí (con F1.T3)

#### F1.T3 — Tests de integración SculptEngine
- **Archivos a leer:** `Sources/Engines/SculptEngine.swift`, `Sources/Engines/Mesh.swift`
- **Archivos a crear:** `Tests/SculptEngineTests.swift` (nuevo)
- **Qué hacer:** Tests para los 10 deformers con mallas pequeñas (cubo, esfera). Verificar que cada deformer modifica vértices y no produce NaN/INF.
- **Qué NO tocar:** No modificar SculptEngine.
- **Verificación:** ≥10 tests de deformers pasando.
- **Criterio de aceptación:** Todos los deformers producen output válido (sin NaN, vértices dentro de bounds razonables).
- **Complejidad:** M | Paralelizable: Sí (con F1.T2)

---

### FASE 2 — Touch → Sculpt Pipeline (Duración: 5-7 días)

**Objetivo:** Conectar input táctil con SculptEngine para esculpir en tiempo real.
**Gate de salida:** Screenshot de iOS Simulator mostrando una esfera deformada por Grab/Inflate.

#### F2.T1 — Conectar MetalView touch handlers con SculptEngine
- **Archivos a leer:** `Core/UI/MetalView.swift`, `Sources/Engines/SculptEngine.swift:51-73`, `Sources/Engines/SatinRenderer.swift:724-738`
- **Archivos a editar:** `Core/UI/MetalView.swift`
- **Qué hacer:** Implementar `touchesMoved` para: (1) raycast contra la malla activa, (2) crear `SculptPoint` con posición de hit + presión + dragDelta, (3) llamar `sculptEngine.apply(at:to:)` o agregar a `pendingStrokes`.
- **Qué NO tocar:** No modificar SculptEngine, no tocar el pipeline de render.
- **Verificación:** No aplica (no hay Mac local). Se verifica via CI build + revisión de código.
- **Criterio de aceptación:** `touchesMoved` contiene código que llama a `SculptEngine`.
- **Complejidad:** L | Paralelizable: No

#### F2.T2 — Integrar sculpt en el render loop sin doble rebuild (depende de F0.T7)
- **Archivos a leer:** `Sources/Engines/SatinRenderer.swift:724-738`
- **Archivos a editar:** `Sources/Engines/SatinRenderer.swift` (si F0.T7 no cubrió esto completamente)
- **Qué hacer:** Asegurar que `applySculpt` modifica buffers GPU existentes sin reconstruir la escena. Usar `MTLBuffer.didModifyRange` para buffers modificados in-place.
- **Qué NO tocar:** No cambiar la API de SculptEngine.
- **Verificación:** CI build pasa.
- **Criterio de aceptación:** `render(in:)` no llama `rebuildSceneFrom` en el path de sculpt.
- **Complejidad:** M | Paralelizable: No (depende de F0.T7)

#### F2.T3 — Feedback visual del pincel (brush cursor)
- **Archivos a leer:** `Core/UI/MetalView.swift`, `Sources/Engines/PincelRenderer.swift` (si existe)
- **Archivos a editar:** `Core/UI/MetalView.swift`
- **Qué hacer:** Dibujar un círculo/wireframe sphere en la posición del cursor 3D para indicar dónde se aplicará el pincel.
- **Qué NO tocar:** No modificar shaders principales.
- **Verificación:** CI build pasa.
- **Criterio de aceptación:** El código incluye renderizado de un indicador de pincel (sphere o ring) en la posición del hit.
- **Complejidad:** M | Paralelizable: Sí (con F2.T4)

#### F2.T4 — Undo/Redo conectado a UI
- **Archivos a leer:** `Sources/Engines/SculptEngine.swift:138-159`, `Features/SculptMode/SculptModeView.swift`
- **Archivos a editar:** `Features/SculptMode/SculptModeView.swift`
- **Qué hacer:** Agregar botones undo/redo en la toolbar de SculptModeView, conectados a `sculptEngine.undo()` y `sculptEngine.redo()`.
- **Qué NO tocar:** No modificar SculptEngine.
- **Verificación:** CI build pasa.
- **Criterio de aceptación:** SculptModeView tiene 2 botones que llaman undo/redo.
- **Complejidad:** S | Paralelizable: Sí

---

### FASE 3 — CAD Mode Funcional (Duración: 7-10 días)

**Objetivo:** Operaciones booleanas CSG funcionales con UI conectada.
**Gate de salida:** Test de CSG: cubo ∪ esfera, cubo − cilindro, cubo ∩ esfera producen mallas válidas con ≥100 triángulos.

#### F3.T1 — Auditar Shape.swift CSG (BSP tree)
- **Archivos a leer:** `Sources/CSG/Shape.swift`, `Sources/CSG/BSPNode.swift`, `Sources/CSG/CSGOperation.swift`, `Sources/CSG/Polygon3D.swift`
- **Archivos a editar:** Ninguno (solo lectura y reporte)
- **Qué hacer:** Leer los 4 archivos CSG. Verificar: ¿BSP tree se construye correctamente? ¿Las 3 operaciones (union, difference, intersection) producen geometría válida? ¿Hay tests? Reportar gaps.
- **Qué NO tocar:** No modificar nada, solo documentar.
- **Verificación:** N/A (análisis estático).
- **Criterio de aceptión:** Documento con hallazgos (gaps, bugs, cobertura de tests) en `docs/auditoria-csg.md`.
- **Complejidad:** M | Paralelizable: Sí

#### F3.T2 — Conectar CAD UI con CSG engines
- **Archivos a leer:** `Features/CADMode/CADModeView.swift`, `Sources/CSG/Shape.swift`
- **Archivos a editar:** `Features/CADMode/CADModeView.swift`
- **Qué hacer:** Implementar toolbar de CAD con botones para primitivas (box, sphere, cylinder, cone, torus) y operaciones (union, difference, intersection). Cada botón crea/modifica la escena.
- **Qué NO tocar:** No modificar los engines CSG.
- **Verificación:** CI build pasa.
- **Criterio de aceptación:** CADModeView tiene ≥8 botones funcionales que modifican `scene3D.models`.
- **Complejidad:** L | Paralelizable: No

#### F3.T3 — Tests de integración CAD
- **Archivos a crear:** `Tests/CADIntegrationTests.swift` (nuevo)
- **Archivos a leer:** `Tests/CSGTests.swift` (existente)
- **Qué hacer:** Extender CSGTests con casos borde: esfera degenerada (radio 0), intersección vacía, diferencia que vacía un objeto, mallas con agujeros.
- **Qué NO tocar:** No modificar engines.
- **Verificación:** ≥15 tests de CSG pasando.
- **Criterio de aceptación:** Tests cubren casos borde y pasan.
- **Complejidad:** M | Paralelizable: Sí

---

### FASE 4 — Animación + Subdivisión + Remesh (Duración: 10-14 días)

**Objetivo:** Animación keyframe funcional, subdivisión Catmull-Clark, remesh dinámico.
**Gate de salida:** 2 modelos animándose simultáneamente a 60fps en iOS Simulator.

#### F4.T1 — AnimationEngine keyframe interpolation
- **Archivos a leer:** `Sources/Engines/AnimationEngine.swift`, `Sources/Engines/AnimationPlaybackController.swift`
- **Archivos a editar:** `Sources/Engines/AnimationEngine.swift`
- **Qué hacer:** Verificar que `evaluateAnimation(deltaTime:)` produce transforms correctos para posición/rotación/escala entre keyframes. Corregir interpolación si es necesario (asegurar slerp para rotaciones, lerp para posición/escala).
- **Qué NO tocar:** No modificar SatinRenderer a menos que sea necesario para la integración.
- **Verificación:** Tests de animación existentes (`AnimationEngineTests.swift` + `AnimationPlaybackTests.swift`) pasan.
- **Criterio de aceptación:** ≥15 tests de animación pasando.
- **Complejidad:** M | Paralelizable: No

#### F4.T2 — UI de timeline/animación
- **Archivos a leer:** `Features/` (buscar vista de animación existente)
- **Archivos a crear:** `Features/AnimationMode/AnimationModeView.swift` (nuevo)
- **Qué hacer:** Crear vista simple de timeline: lista de keyframes, botón play/pause, slider de tiempo. Conectar con AnimationEngine.
- **Qué NO tocar:** No modificar SatinRenderer.
- **Verificación:** CI build pasa.
- **Criterio de aceptación:** AnimationModeView renderiza y se conecta a AnimationEngine.
- **Complejidad:** L | Paralelizable: Sí (con F4.T3)

#### F4.T3 — Catmull-Clark subdivision
- **Archivos a leer:** `Sources/Engines/SubdivisionEngine.swift` (si existe)
- **Archivos a crear/editar:** `Sources/Engines/SubdivisionEngine.swift`
- **Qué hacer:** Implementar o verificar Catmull-Clark: (1) calcular face points, (2) calcular edge points, (3) ajustar vertex points, (4) reconstruir malla. Test con cubo → esfera.
- **Qué NO tocar:** No modificar otros engines.
- **Verificación:** CI build + test: cubo subdividido 2 veces tiene ≥50 caras.
- **Criterio de aceptación:** Subdivisión produce malla válida sin caras degeneradas.
- **Complejidad:** L | Paralelizable: Sí (con F4.T2)

#### F4.T4 — Remesh/Dynamic Topology
- **Archivos a leer:** `Sources/Engines/DynamicTopologyEngine.swift` (si existe)
- **Archivos a crear/editar:** `Sources/Engines/DynamicTopologyEngine.swift`
- **Qué hacer:** Implementar remesh local: detectar caras con área > umbral, subdividir; detectar caras con área < umbral, colapsar. Integrar con SculptEngine para que el sculpt dispare remesh donde la densidad lo requiera.
- **Qué NO tocar:** No modificar SculptEngine (solo agregar callback opcional).
- **Verificación:** CI build + test de remesh.
- **Criterio de aceptación:** Remesh produce malla con densidad adaptativa.
- **Complejidad:** L | Paralelizable: No (depende de F4.T3)

---

### FASE 5 — Hybrid Mode + Export Pipeline (Duración: 5-7 días)

**Objetivo:** Modo híbrido funcional (capas CAD+sculpt+paint) y exportación a formatos profesionales.
**Gate de salida:** Exportar una escena híbrida a OBJ + STL y verificar archivos válidos con visor externo.

#### F5.T1 — Lógica de capas híbridas
- **Archivos a leer:** `Features/HybridMode/HybridModeView.swift`
- **Archivos a editar:** `Features/HybridMode/HybridModeView.swift`
- **Qué hacer:** Implementar sistema de capas: cada capa puede ser tipo CAD, Sculpt, o Paint. Las capas se renderizan en orden. El modo activo determina qué capa se edita.
- **Qué NO tocar:** No modificar SatinRenderer ni engines.
- **Verificación:** CI build pasa.
- **Criterio de aceptación:** Se pueden crear ≥3 capas de tipos distintos.
- **Complejidad:** M | Paralelizable: No

#### F5.T2 — ExportService verificación y fixes
- **Archivos a leer:** `Core/Services/ExportService/ExportService.swift`
- **Archivos a editar:** `Core/Services/ExportService/ExportService.swift`
- **Qué hacer:** Corregir export GLTF (escribe buffer .bin). Verificar que OBJ, STL, USDZ, STEP, GLTF, FBX producen archivos válidos. Agregar tests de roundtrip (exportar → verificar estructura).
- **Qué NO tocar:** No modificar engines de exportación profesional (STEP/IGES).
- **Verificación:** Tests de exportación pasan para ≥4 formatos.
- **Criterio de aceptación:** Archivos exportados abren en visores externos (Blender, Preview).
- **Complejidad:** L | Paralelizable: No

#### F5.T3 — UI de exportación con progreso
- **Archivos a leer:** `Features/ExportMode/ExportView.swift`, `ViewModels/ExportViewModel.swift`
- **Archivos a editar:** `Features/ExportMode/ExportView.swift`
- **Qué hacer:** Mejorar UI de exportación: selector de formato, opciones de calidad/resolución, barra de progreso real (no simulada), botón compartir (ShareSheet iOS).
- **Qué NO tocar:** No modificar ExportService.
- **Verificación:** CI build pasa.
- **Criterio de aceptación:** ExportView muestra progreso real durante exportación.
- **Complejidad:** M | Paralelizable: Sí

---

### FASE R — Riesgo Satin Archivado: Vendorización (Duración: 3-5 días)

**Objetivo:** Eliminar dependencia del repo archivado Hi-Rez/Satin.
**Gate de salida:** `Package.swift` referencia Satin como dependencia local (vendorizada), build CI pasa sin descargar de GitHub.

#### FR.T1 — Decidir estrategia (vendor vs fork vs migrar)
- **Archivos a leer:** `Hi-Rez-Satin/` (directorio untracked, ~350 archivos)
- **Archivos a editar:** Ninguno aún
- **Qué hacer:** Evaluar 3 opciones:
  - A: Vendorizar Satin (copiar fuentes a `ios-app/AppForgeStudio/Vendor/Satin/`, Package.swift → `.package(path: "Vendor/Satin")`). PRO: sin dependencia externa. CON: 210 .metal + ~140 .swift extra.
  - B: Forkear a `iwannatrip02-sys/Satin` (paquete remoto propio). PRO: repo separado, limpio. CON: mantener 2 repos.
  - C: Migrar a otro framework (MetalKit directo, TheBrick, Alloy). PRO: más moderno. CON: reescribir SatinRenderer (~800 líneas).
- **Qué NO tocar:** No modificar Package.swift hasta decidir.
- **Verificación:** Documento con recomendación en `docs/decision-satin-vendor.md`.
- **Criterio de aceptación:** Decisión documentada con pros/cons.
- **Complejidad:** M | Paralelizable: No (decisión de arquitectura)

#### FR.T2 — Ejecutar vendorización/fork
- **Archivos a leer:** `Hi-Rez-Satin/Package.swift`, `ios-app/AppForgeStudio/Package.swift`
- **Archivos a editar:** `ios-app/AppForgeStudio/Package.swift`
- **Qué hacer:** Según decisión de FR.T1:
  - Si vendorizar: copiar `Hi-Rez-Satin/Sources/` a `ios-app/AppForgeStudio/Vendor/Satin/`, cambiar Package.swift a `.package(path: "Vendor/Satin")`.
  - Si forkear: crear repo `iwannatrip02-sys/Satin`, push, cambiar URL en Package.swift.
- **Qué NO tocar:** No modificar fuentes de Satin (solo mover/copiar).
- **Verificación:** CI build pasa con la nueva referencia de Satin.
- **Criterio de aceptación:** `grep "Hi-Rez/Satin" ios-app/AppForgeStudio/Package.swift` devuelve 0 resultados.
- **Complejidad:** M | Paralelizable: No

---

### FASE 6 — Pipeline de Release Gratuito (Duración: 3-5 días)

**Objetivo:** Generar `.ipa` unsigned en CI, documentar instalación para testers.
**Gate de salida:** `.ipa` descargable desde GitHub Actions artifacts, instalable en iPad físico vía AltStore/Sideloadly.

#### F6.T1 — CI: generar .ipa unsigned
- **Archivos a leer:** `.github/workflows/build.yml`, `ExportOptions.plist`
- **Archivos a editar:** `.github/workflows/build.yml`
- **Qué hacer:** Agregar paso `xcodebuild archive -project ... -scheme AppForgeStudio -sdk iphoneos -destination 'generic/platform=iOS' -archivePath AppForgeStudio.xcarchive CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO`. Luego `xcodebuild -exportArchive -archivePath AppForgeStudio.xcarchive -exportOptionsPlist ExportOptions.plist -exportPath export/`. Subir `.ipa` como artifact.
- **Qué NO tocar:** No modificar scheme, no cambiar bundle ID.
- **Verificación:** CI build produce artifact `.ipa` descargable.
- **Criterio de aceptación:** Artifact contiene `AppForgeStudio.ipa` > 10MB.
- **Complejidad:** M | Paralelizable: No

#### F6.T2 — Documentar instalación para testers
- **Archivos a crear:** `docs/INSTALL_TESTERS.md`
- **Archivos a leer:** N/A
- **Qué hacer:** Escribir guía paso a paso con screenshots para: (1) descargar .ipa de GitHub Actions, (2) instalar AltStore/Sideloadly en Windows/Mac, (3) sideloadear el .ipa en iPad, (4) confiar en el certificado de desarrollador en Settings.
- **Qué NO tocar:** Nada de código.
- **Verificación:** N/A (documentación).
- **Criterio de aceptación:** Documento cubre el flujo completo Windows→iPad sin Mac.
- **Complejidad:** S | Paralelizable: Sí

#### F6.T3 — Landing page / README open-source
- **Archivos a leer:** `README.md` (raíz del repo)
- **Archivos a editar:** `README.md`
- **Qué hacer:** Escribir README atractivo: badges (CI status, license, platform), GIFs/screenshots del simulador, features, quickstart para developers, enlace a INSTALL_TESTERS.md.
- **Qué NO tocar:** Nada de código.
- **Verificación:** N/A (documentación).
- **Criterio de aceptación:** README tiene badges, screenshots, y quickstart.
- **Complejidad:** S | Paralelizable: Sí

---

### FASE 7 — Pulido y Lanzamiento Open-Source (Duración: 5-7 días)

**Objetivo:** App estable, documentada, lista para anuncio público.
**Gate de salida:** Repo público con README, CI verde, .ipa disponible, ≥1 tester externo verificó instalación.

#### F7.T1 — Eliminar archivos huérfanos y limpiar repo
- **Archivos a leer:** `git status --short` (ver sección 0.1)
- **Archivos a editar/eliminar:** `nul` (raíz), `.gitignore` (agregar `nul`, `Hi-Rez-Satin/` si no se vendoriza)
- **Qué hacer:** Eliminar `nul`. Decidir destino de `Hi-Rez-Satin/` (si no se vendorizó en FR, agregar a .gitignore o eliminar). Archivar docs viejas a `docs/archive/`.
- **Qué NO tocar:** No eliminar archivos fuente.
- **Verificación:** `git status --short` muestra solo cambios intencionales.
- **Criterio de aceptación:** Cero archivos basura en repo.
- **Complejidad:** S | Paralelizable: No

#### F7.T2 — Performance audit (Instruments / Metal Debugger)
- **Archivos a leer:** `Sources/Engines/SatinRenderer.swift`, shaders `.metal`
- **Archivos a editar:** Según hallazgos
- **Qué hacer:** Perfilar en iOS Simulator con GPU debugger. Identificar: (1) overdraw excesivo, (2) llamadas redundantes a `makeBuffer`, (3) texturas no liberadas. Corregir top 3 issues.
- **Qué NO tocar:** No reescribir pipelines completos.
- **Verificación:** Frame time <16ms (60fps) en iPad Pro Simulator con ≥5 modelos en escena.
- **Criterio de aceptación:** 60fps sostenidos con escena de complejidad media.
- **Complejidad:** L | Paralelizable: No

#### F7.T3 — Anuncio público (GitHub Release + comunidades)
- **Archivos a crear:** GitHub Release v1.0.0-alpha
- **Archivos a leer:** N/A
- **Qué hacer:** Crear release en GitHub con .ipa adjunto, changelog, y enlaces a documentación. Postear en r/iOSProgramming, r/3Dmodeling, Hacker News "Show HN", dev.to.
- **Qué NO tocar:** Nada de código.
- **Verificación:** Release creado en GitHub, ≥1 post en comunidad.
- **Criterio de aceptación:** Release v1.0.0-alpha visible en GitHub Releases.
- **Complejidad:** S | Paralelizable: Sí

---

## 3. Riesgos y Mitigaciones

| Riesgo | Probabilidad | Impacto | Mitigación | Fase |
|--------|-------------|---------|------------|------|
| Satin archivado → bugs sin fix | ALTA | ALTO | Vendorizar en FR (Fase R). Si hay bugs críticos, fix directo en vendor. | FR |
| OCCTSwift desaparece o es incompatible | MEDIA | ALTO | CSG nativo ya implementado (Shape.swift). OCCTSwift solo para CAD avanzado. Plan B: migrar a CSG nativo completo. | F3 |
| CI macOS runner deja de ser gratis | BAJA | MEDIO | GitHub Actions mantiene macOS gratis para repos públicos. Plan B: compilar en Mac Mini propio. | F6 |
| Apple rechaza instalación sin developer account | MEDIA | BAJO | AltStore/Sideloadly funciona sin cuenta paga (7-day cert). TestFlight requiere $99/año → postergado. | F6 |
| Tests no pasan por diferencias de entorno CI vs local | MEDIA | MEDIO | Usar solo iOS Simulator (no device). Tests determinísticos, sin timeouts frágiles. | F1 |
| Shaders Metal fallan en CI por versión de GPU | BAJA | BAJO | CI usa GPU del runner (Apple Silicon M4). Si falla, usar `MTLDevice.requiresCustomTextureFormats` checks. | F0 |
| BUG1 (float3 padding) rompe rendering PBR completamente | ALTA (ya presente) | CRÍTICO | Fix prioritario en F0.T2. Sin fix, todos los materiales PBR se ven corruptos. | F0 |
| BUG9 (rebuild cada frame) causa framerate <30fps | ALTA | ALTO | Fix en F0.T7. Sin fix, animación y sculpt son inutilizables en devices reales. | F0 |

---

## 4. Mapa de Dependencias entre Fases

```
F0 (CI + Bugs) ──┬──> F1 (Tests) ──> F2 (Sculpt) ──> F4 (Animación) ──> F5 (Hybrid) ──> F7 (Pulido)
                 │
                 ├──> F3 (CAD) ──────────────────────> F5 (Hybrid)
                 │
                 └──> FR (Satin Vendor) ──> F6 (Release) ──> F7 (Pulido)
```

**Bloqueos:**
- F1 depende de F0 (tests no compilan si CI no builda)
- F2 depende de F0.T7 (sculpt sin fix de rebuild es inutilizable)
- F2 y F3 son independientes entre sí
- F4 depende de F2 para el pipeline de render estable
- F5 depende de F2, F3, F4 (hybrid integra los 3 modos)
- F6 depende de FR (vendor) para tener dependencias estables
- F7 depende de F5, F6 (pulido final)

**Paralelismo posible:**
- F0.T2, F0.T3, F0.T5, F0.T6 son paralelizables (bugs independientes)
- F2 y F3 pueden ejecutarse en paralelo (CAD y Sculpt no comparten código)
- F4.T2 y F4.T3 son paralelizables
- F6.T2 y F6.T3 son paralelizables (documentación)

---

## 5. Protocolo para Agentes Ejecutores

### 5.1 Reglas de GOTCHI.md (obligatorio)

1. **Un módulo a la vez.** Cada tarea toca exactamente los archivos listados en "Archivos a editar". Si se necesita modificar algo fuera de la lista, detenerse y reportar.
2. **float3 padding.** Todo struct Swift que se pase a GPU vía `setVertexBytes`/`setFragmentBytes` DEBE tener padding manual para emular la alineación de `float3` de Metal (16 bytes). Regla: cada grupo de 3 floats va seguido de 1 float de padding. Verificar con `MemoryLayout<MiStruct>.stride`.
3. **NO compilar local.** No hay Mac ni Xcode. Toda verificación es vía `git push` a branch + `gh run watch`.
4. **Pegar verificación literal.** Al reportar "hecho", pegar la salida literal del comando de verificación (ej: output de `gh run view --log`, o resultado de `grep`). No parafrasear.
5. **NO commit sin orden.** Cada agente trabaja en su branch. Solo se mergea a `main` cuando el gate de la fase está completo y verificado.

### 5.2 Flujo de trabajo estándar por tarea

```
1. git checkout -b f<N>/<slug>
2. Leer archivos listados en "Archivos a leer"
3. Editar SOLO archivos listados en "Archivos a editar"
4. git add + git commit -m "f<N>: <descripción breve>"
5. git push origin f<N>/<slug>
6. gh run watch
7. Reportar: [PASA/NO PASA] + evidencia literal
```

### 5.3 Criterio de aceptación binario

- **PASA:** CI verde + verificación específica de la tarea OK.
- **NO PASA:** CI rojo O verificación específica falla. En este caso: adjuntar `build.log` o `test.log` del artifact de CI, analizar error, proponer fix.

### 5.4 Prohibiciones

- NO usar `swift build` ni `xcodebuild` local (no hay toolchain)
- NO modificar `.github/workflows/build.yml` sin nombrar la branch `f0/ci-*`
- NO hacer force push a `main`
- NO mergear sin que `gh run watch` muestre ✅ en el branch
- NO editar archivos `.metal` y `.swift` en el mismo commit (separar cambios de shaders y Swift)

---

## Resumen de Fases

| Fase | Nombre | Micro-tareas | Duración est. | Gate |
|------|--------|-------------|---------------|------|
| F0 | CI Verde + Bugs | 7 (T1-T7) | 3-5 días | CI build + test verde, 5 bugs corregidos |
| F1 | Tests y Cobertura | 3 (T1-T3) | 3-5 días | ≥65 tests pasando |
| F2 | Touch→Sculpt | 4 (T1-T4) | 5-7 días | Escultura táctil funcional en simulador |
| F3 | CAD Funcional | 3 (T1-T3) | 7-10 días | CSG booleano verificado con tests |
| F4 | Animación+Subdivisión | 4 (T1-T4) | 10-14 días | 2 modelos animándose a 60fps |
| F5 | Hybrid+Export | 3 (T1-T3) | 5-7 días | Export OBJ+STL válido |
| FR | Satin Vendorizado | 2 (T1-T2) | 3-5 días | Build sin dep externa archivada |
| F6 | Release Gratuito | 3 (T1-T3) | 3-5 días | .ipa en GitHub Actions artifacts |
| F7 | Pulido+Lanzamiento | 3 (T1-T3) | 5-7 días | Release v1.0.0-alpha público |
| **TOTAL** | | **32 tareas** | **44-65 días** | |

---

## Firmas de Verificación

- [ ] F0 gate: CI verde con tests — Fecha: ______ | Ejecutor: ______ | Evidencia: ______
- [ ] F1 gate: ≥65 tests pasando — Fecha: ______ | Ejecutor: ______ | Evidencia: ______
- [ ] F2 gate: Sculpt touch funcional — Fecha: ______ | Ejecutor: ______ | Evidencia: ______
- [ ] F3 gate: CSG verificado — Fecha: ______ | Ejecutor: ______ | Evidencia: ______
- [ ] F4 gate: Animación 60fps — Fecha: ______ | Ejecutor: ______ | Evidencia: ______
- [ ] F5 gate: Export válido — Fecha: ______ | Ejecutor: ______ | Evidencia: ______
- [ ] FR gate: Build sin Satin remoto — Fecha: ______ | Ejecutor: ______ | Evidencia: ______
- [ ] F6 gate: .ipa generado en CI — Fecha: ______ | Ejecutor: ______ | Evidencia: ______
- [ ] F7 gate: Release v1.0.0-alpha — Fecha: ______ | Ejecutor: ______ | Evidencia: ______
