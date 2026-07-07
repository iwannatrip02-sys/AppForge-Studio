# Análisis de Code Review — AppForge Studio
> Fecha: 2026-05-27 | Post-verificación canónicos

## Resumen de verificación

| Archivo Canónico | Estado | Issues |
|---|---|---|
| GOTCHI.md | Desactualizado | Dice Satin "s1ddok", pero Package.swift usa Hi-Rez/Satin 13.0.0 |
| BRAIN.md | v2 | Dice 49 engines, hay 54. Dice "49 tests", hay 7 archivos de test |
| TODO.md | OK | 15 pendientes, 3 bloqueos, ~16 completados |
| DECISIONS.md | OK | Decisiones de arquitectura registradas |

## Estructura real vs BRAIN

| Directorio | BRAIN.md | Disco (glob) | Delta |
|---|---|---|---|
| Sources/Engines/ | 49 files | 54 .swift | +5 (AssemblyEngine, BooleanEngine, BrushStroke, MaterialEditorView, OCCTEngine) |
| Sources/CSG/ | 4 files | 3 + LegacyCSG/3 | CSG principal en LegacyCSG/ |
| Sources/CAD/ | 2 files | 2 files | OK |
| Sources/Services/ | 5 files | 8 files | +3 (CADProfessionalEngine, CADSculptBridge, OCCTBridge) |
| Core/UI/ | 25 files | 29 files | OK (incluye Managers, Theme, Services) |
| Tests/ | 49 tests | 7 archivos | BRAIN inflado — son 7 archivos, no 49 tests |

## Bugs — análisis uno por uno

### BUG1: layout GPU PBR (float3 padding a 16 bytes)
**Archivo:** `Sources/Engines/SatinRenderer.swift`
**Veredicto:** ✅ YA RESUELTO. `GPUPBRMaterial`, `GPUPointLight`, `GPUDirectionalLight` tienen `_pad1` y `_pad2` correctamente declarados (líneas 30, 35, 40, 45).

### BUG2: updateAnimation() doble por frame
**Archivos:** `Sources/Engines/AnimationEngine.swift` + `AnimationPlaybackController.swift`
**Veredicto:** 🔍 PENDIENTE VERIFICAR. AnimationEngine usa CADisplayLink. Hay que verificar que no se llame update() dos veces en el mismo callback.

### BUG3: UInt16 → UInt32 para mallas >65k vértices
**Archivo:** `Sources/Engines/Mesh.swift`
**Veredicto:** ✅ YA RESUELTO. Línea 10: `var indices: [UInt32]`.

### BUG5: normal matrix bajo escala no-uniforme
**Archivo:** Shaders .metal (no leídos aún)
**Veredicto:** 🔍 PENDIENTE. Requiere leer los shaders para verificar si usan la transpose(inverse(modelMatrix)) para normales.

### BUG7: grab deformer dirección contraria
**Archivo:** `Sources/Engines/GrabDeformer.swift`
**Veredicto:** ❌ BUG CONFIRMADO. Línea 7: `vertex.position += point.normal * influence`. Un grab debe mover en dirección del delta del touch (dragDelta), no en la normal de la superficie. Fix: cambiar `point.normal` → `point.dragDelta`.

### BUG9: rebuildSceneFrom llamado cada frame (60 allocs/seg)
**Archivos:** `Sources/Engines/Scene3D.swift` + `SatinRenderer.swift`
**Veredicto:** 🔍 PENDIENTE. Scene3D tiene `vertexProvider` y `vertexUpdater` pero hay que rastrear dónde se llama `rebuildSceneFrom` en cada frame.

## Bugs que NO se pueden verificar sin Mac
- Compilación real (necesita Xcode + toolchain Apple)
- Tests en iOS Simulator
- SatinCore narrowing errors (C++ en Triangulator.mm)

## Archivos detectados adicionales (no en BRAIN)
- `Hi-Rez-Satin/` — clon completo del framework Satin (350+ archivos). Untracked.
- `nul` — artefacto Windows (untracked, debe ignorarse o borrarse)
- 28 archivos en `docs/sesiones/` — ruido de sesiones anteriores

## Prioridad de corrección (sin Mac)

1. **BUG7 (GrabDeformer)** — 1 línea, trivial
2. **BUG2 (updateAnimation doble)** — verificar y corregir
3. **BUG9 (rebuildSceneFrom)** — verificar y corregir
4. **BUG5 (normal matrix)** — requiere leer .metal shaders
5. **BUG1** — ya resuelto, marcar como done
6. **BUG3** — ya resuelto, marcar como done
