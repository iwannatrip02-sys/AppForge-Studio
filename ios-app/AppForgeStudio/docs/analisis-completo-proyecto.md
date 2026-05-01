# AppForge Studio — Análisis Completo del Proyecto
> Actualizado: 2026-05-01 06:07 UTC

## 1. Resumen
App iOS nativa de pintura 3D + escultura paramétrica + CAD + animación + exportación a impresión 3D.
Stack: SwiftUI + Metal 2 + Satin v0.3.0 + ModelIO + OCCTSwift.
Workspace real: `ios-app/AppForgeStudio` en `C:\Users\USUARIO\Projects\appforge-studio\`

## 2. Fases completadas

### Fase 1: Pintura 3D (COMPLETA)
- PaintRenderer con pinceles (BrushEngine)
- Soporte de strokes 3D sobre modelos
- Interfaz de usuario con ToolbarView

### Fase 2: Escultura (COMPLETA)
- SculptMode con CSGEngine
- SubdivisionEngine para suavizado
- Modelos con buffers Metal

### Fase 3: CAD (COMPLETA)
- CADMode con GeometryConstraintManager
- CADHistoryTree para deshacer/rehacer
- Operaciones booleanas primitivas

### Fase 4: Animación (COMPLETA) ✅
- **AnimationEngine.swift** en `Core/Engines/` (4504 bytes)
  - Struct Keyframe con time, translation, rotation (slerp), scale
  - Struct Clip con keyframes por nodo y loop
  - evaluateAnimation(deltaTime:) con interpolación entre keyframes
- **SatinRenderer.swift** — updateAnimation() conectado via animationEngine
  - Evalúa transforms y los aplica a scene3D.models
  - Callback onTransformsApplied para depuración
- **AnimationModeView.swift** — UI con play/pause, slider de tiempo, TimelineView
- **Model.swift** — ya tiene transform computado (T * R * S) y setters
- **Scene3D.swift** — estructura de escena con models array

## 3. Archivos clave del proyecto

| Archivo | Ruta | Función |
|---------|------|--------|
| AppForgeStudioApp.swift | AppForgeStudio/ | Entry point con NavigationStack y modos |
| SatinRenderer.swift | AppForgeStudio/ | Renderer Metal con conexión animación |
| SatinMesh.swift | AppForgeStudio/ | Mesh wrapper para Satin |
| AnimationEngine.swift | Core/Engines/ | Motor de animación con keyframes |
| BrushEngine.swift | Core/Engines/ | Motor de pinceles 3D |
| CSGEngine.swift | Core/Engines/ | Motor CSG para escultura |
| Scene3D.swift | Models/ | Estructura de escena |
| Model.swift | Models/ | Entidad 3D con transform |
| AnimationModeView.swift | Features/AnimationMode/ | UI del modo animación |

## 4. Pendientes (Fase 5 y 6)
1. Validar exportación STEP (CadExporter/ExportService)
2. Unit tests para AnimationEngine (XCTest)
3. Tests de integración render + animación

## 5. Decisiones técnicas
- Workspace unificado en `ios-app/AppForgeStudio` con subcarpetas canónicas
- AnimationEngine como ObservableObject para binding SwiftUI
- Keyframes con interpolación slerp (rotación) y mix (posición/scale)
- Transform aplicado directamente a scene3D.models[i].transform
