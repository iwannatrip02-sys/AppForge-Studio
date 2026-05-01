# TODO.md

## COMPLETED
- [x] t36: Conectar AnimationEngine con SatinRenderer para playback real
  - Creado AnimationEngine.swift en Core/Engines/ (Keyframe, Clip, evaluateAnimation)
  - SatinRenderer.updateAnimation() evalua transforms y los aplica a scene3D.models
  - AnimationModeView ya bindea el engine con UI (play/pause, slider, TimelineView)
  - Fase 4 animacion COMPLETA

## PENDIENTES
- [ ] Fase 5: Validar exportacion STEP con modelo real (CadExporter/ExportService)
- [ ] Fase 6: Unit tests para AnimationEngine (XCTest)
- [ ] Fase 6: Tests de integracion render + animacion
