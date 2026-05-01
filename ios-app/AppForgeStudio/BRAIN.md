# AppForge Studio — Project Brain
> v76 | Updated: 2026-05-01 06:07 UTC

## ENTIDADES CLAVE
- AnimationEngine (modulo) — Motor de animacion con keyframes e interpolacion en Core/Engines/AnimationEngine.swift.
- SatinRenderer (modulo) — Renderer principal con conexion a AnimationEngine via updateAnimation() en AppForgeStudio/SatinRenderer.swift.
- Scene3D (modelo) — Escena con modelos, camara, luces en Models/Scene3D.swift.
- Model (modelo) — Entidad 3D con transform, buffers, color en Models/Model.swift.
- AnimationModeView (UI) — Vista de modo animacion con timeline, play/pause, slider en Features/AnimationMode/AnimationModeView.swift.

## ESTADO ACTUAL
Fase 4 (animacion) COMPLETA: AnimationEngine creado en Core/Engines/ con keyframes, interpolacion lineal+slerp, clips, loop. SatinRenderer.updateAnimation() evalua transforms y los aplica a scene3D.models. AnimationModeView ya bindea engine con togglePlayPause(), slider de tiempo y TimelineView.

## PROXIMAS ACCIONES
1. [Fase 5] Validar exportacion STEP (CadExporter/ExportService)
2. [Fase 6] Escribir unit tests para AnimationEngine (XCTest)
3. [Fase 6] Agregar tests de integracion render + animacion

## Ruta workspace
C:\Users\USUARIO\Projects\appforge-studio\ios-app\AppForgeStudio
