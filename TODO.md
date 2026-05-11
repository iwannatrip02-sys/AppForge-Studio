# AppForge Studio — TODO.md
> Actualizado: 2026-05-11 16:57 UTC

## Foco actual
- Generar .ipa sin firma para AltStore + Beta TestFlight v0.9

## Completados (sesion actual)
- [x] USDZ para AR QuickLook (ARQuickLookView + ExportView + sheet)
- [x] Internacionalizacion ES/EN (Localizable.xcstrings es + en)
- [x] Animacion de morph targets entre mallas (MorphEngine + AnimationEngine + tests)
- [x] IBL para PBR: diffuse irradiance + specular prefilter + BRDF LUT (IBLPipeline.swift implementado)
- [x] CAD-8: ConstraintOverlayView integrado en CADModeView

## Completados (sesiones anteriores)
- [x] BUG1-9: padding GPU structs, updateAnimation, UInt32, normal matrix, stroke aspect, grab deformer, currentMode, Package.swift, deltaTime Double
- [x] CAD-1 a CAD-7: sistema CAD completo (entities, solver, history, manager, sketch, extrude, UI)
- [x] Fase 1A-7: pinceles, sculpt, subdivision, boolean CAD, animation, export, tests, cache, dark mode, CI/CD
- [x] FBX/Collada/STEP export, Material Editor PBR, analisis competitivo

## Pendientes inmediatos (para iPad)
- [ ] **CAD-9** — Conectar GeometryConstraintManager.shared con Scene3D.constraintManager
- [ ] Generar .ipa sin firma para AltStore
- [ ] Ejecutar suite de tests en GitHub Actions
- [ ] Beta TestFlight v0.9
- [ ] Validar render loop (paint+sculpt+CAD+animation) en simulador

## Pendientes Fase 8-10
- [ ] Fase 8: Integrar OCCTSwift como kernel CAD parametrico
- [ ] Fase 8: Sketch 2D con PencilKit + snapping inteligente
- [ ] Fase 8: Extrusion/Revolucion/Sweep con preview Metal
- [ ] Fase 8: Timeline parametrico DAG con undo/redo
- [ ] Fase 9: Gestos intuitivos (pinch-to-extrude, tap-drag selection)
- [ ] Fase 9: Constraints automaticas (paralelismo, concentricidad, tangencia)
- [ ] Fase 10: Boolean operations en GPU (compute shaders)
- [ ] Fase 10: Assemblies con jerarquia de componentes
- [ ] Soporte de texture maps en PBRMaterialUniforms
- [ ] Tangent space en PBRShaders.metal para normal maps

## Notas
- Compilacion local: Swift Toolchain no disponible en Windows 11. Workaround: push a GitHub CI o generar .ipa via xcodebuild en macOS.
