# Bug Fix Sprint — AppForge Studio
> 2026-05-11 | 6 bugs corregidos en 5 archivos

## Bugs Encontrados y Corregidos

### 1. Force Unwrap en AnimationEngine.swift (línea 157)
- **Problema**: `var next = kfs.last!` — crash si kfs está vacío
- **Fix**: `guard let next = kfs.last else { continue }`
- **Archivo**: `Core/Engines/AnimationEngine.swift`

### 2. Force Unwrap en AnimationEngine.swift (línea 370)
- **Problema**: `var next = sorted.last!` — crash si sorted está vacío
- **Fix**: `guard let next = sorted.last else { continue }`
- **Archivo**: `Core/Engines/AnimationEngine.swift`

### 3. Force Unwrap en CADModeView.swift (línea 510)
- **Problema**: `FileManager.default.urls(...).first!` — crash si no hay document directory
- **Fix**: `guard let documentsDir = ... else { return }`
- **Archivo**: `Features/CADMode/CADModeView.swift`

### 4. Force Unwrap en CADModeView.swift (línea 524)
- **Problema**: Mismo force unwrap en función de exportación STL
- **Fix**: `guard let documentsDir = ... else { return }`
- **Archivo**: `Features/CADMode/CADModeView.swift`

### 5. Ausencia de Debounce en GestureHandler.swift
- **Problema**: Gestos sin debounce — múltiples disparos en un solo touch
- **Fix**: Añadido `shouldFire(_:)` con `debounceInterval: 0.1s` y `lastGestureTime` tracker por callback key
- **Archivo**: `Features/CADMode/GestureHandler.swift`

### 6. SDFEngine.swift — Falta de bounds checking en GPU dispatch
- **Problema**: `marchingCubesGPU` no validaba grid size antes de dispatch Metal
- **Fix**: `guard gs > 1, gs < 256` + `guard grid3D.width > 0 && grid3D.height > 0 && grid3D.depth > 0`
- **Archivo**: `Core/Engines/SDFEngine.swift`

### 7. AssemblyEngine.swift — Sin detección de ciclos
- **Problema**: Jerarquía de nodos podía tener ciclos → stack overflow
- **Fix**: `visited: inout Set<UUID>` en `worldTransform()` y `allModelIDs()`, `validateNoCycles(from:)`
- **Archivo**: `Core/Engines/AssemblyEngine.swift`

### Ya era correcto (no requirió fix)
- **BooleanComputeShaders.metal**: usa `float*` (4-byte alineado), no `bool*`. Bounds checks presentes.
- **Shaders PBR**: sin bugs de alineamiento detectados.

## Archivos Modificados
1. `Core/Engines/AnimationEngine.swift` — 2 force unwraps -> guard let
2. `Core/Engines/SDFEngine.swift` — 2 guards de validación + originBuffer fix
3. `Core/Engines/AssemblyEngine.swift` — cycle detection en visited set
4. `Features/CADMode/CADModeView.swift` — 2 force unwraps -> guard let
5. `Features/CADMode/GestureHandler.swift` — debounce system añadido

## Estado Post-Fix
- 0 force unwraps peligrosos detectados en código activo (Core/ + Features/)
- GPU dispatch validado con bounds checks
- Assemblies a prueba de ciclos
- Gestos con debounce de 100ms