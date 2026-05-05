# AppForge Studio — TODO.md
> Actualizado: 2026-05-04 | Prioridades basadas en code review externo

## FOCO ACTUAL — Corregir bugs críticos antes de CI

## BUGS APLICADOS (commit b6766b4)

- [x] **BUG1** — Agregar padding a GPUPBRMaterial, GPUDirectionalLight, GPUPointLight en SatinRenderer.swift (`var _pad: Float = 0` tras cada float3)
- [x] **BUG2** — Eliminar `updateAnimation()` al inicio de `SatinRenderer.render(in:)` (ya se llama en Coordinator.draw)
- [x] **BUG3** — Cambiar `[UInt16]` a `[UInt32]` en createBuffersFromMeshes() y `.uint16` a `.uint32` en drawIndexedPrimitives
- [x] **BUG5** — Fix normal matrix en Shaders.metal: usar `transpose(inverse(float3x3(modelMatrix)))` en vertex_main y pbr_vertex_main
- [x] **BUG6** — Fix stroke aspect ratio: pasar viewport aspect como uniform en lugar de `center.w`
- [x] **BUG9** — Desacoplar applyTransformsToScene() de rebuildSceneFrom(): pasar modelMatrix como uniform, no reconstruir buffers

## ALTA PRIORIDAD

- [x] **BUG7** — Fix grab deformer: agregar `dragDelta: SIMD3<Float>` a SculptPoint, usar en case .grab
- [x] **BUG8** — Fix currentMode en CanvasViewModel: no hardcodear .hybrid
- [x] **BUG4** — Package.swift: mattrajca -> s1ddok/Satin.git
- [x] **BUG2** — SatinRenderer.swift: deltaTime Double en vez de Float
- [x] **BUG5** — Shaders.metal: normal matrix con inverse(transpose)
- [ ] **SIGUIENTE** — Push a CI y verificar build en macos-14/Xcode 16.1 y verificar que build-ios.yml pasa en macos-14/Xcode 16.1
- [ ] Fix smooth deformer: Laplacian averaging (promediar vecinos en radio, no mover hacia brush center)

## MEDIA PRIORIDAD

- [ ] IBL para PBR: diffuse irradiance + specular prefilter + BRDF LUT
- [ ] Soporte de texture maps en PBRMaterialUniforms (albedo/roughness/metallic/normal)
- [ ] Tangent space en PBRShaders.metal para normal maps
- [ ] Beta testing: AltStore + TestFlight
- [ ] Animación de morph targets entre mallas
- [ ] USDZ para AR QuickLook
- [ ] Internacionalización

## COMPLETADO

- [x] Fase 1A: Sistema pinceles (BrushStroke, PaintRenderer, Shaders.metal 4 tipos)
- [x] Fase 1B: PincelRenderer Metal GPU
- [x] Fase 2A: SculptEngine 8 deformadores
- [x] Fase 2B: SubdivisionEngine Catmull-Clark
- [x] Fase 3A: CAD booleano (OCCTEngine)
- [x] Fase 3B: CAD historial (CADHistoryTree undo/redo 50 pasos)
- [x] Fase 3C: GeometryConstraintManager con solver Gauss-Seidel
- [x] Fase 4: AnimationEngine keyframes + 7 easings + SatinRenderer
- [x] Fase 5: ExportService OBJ/STL/USDZ/STEP/GLTF
- [x] Fase 6: Tests unitarios (23 casos)
- [x] Fase 7: ModelCacheService + dark mode + LoadingScreenView + haptics + onboarding
- [x] CI/CD GitHub Actions (build-ios.yml, macos-14, Xcode 16.1)
- [x] AltStore deploy scripts
- [x] SimdTransform + selectedTransform en CanvasViewModel
- [x] Material Editor PBR (MaterialEditorView, MaterialEditorViewModel, presets)
- [x] Análisis competitivo vs Shapr3D/Nomad Sculpt
- [x] FBX y Collada export
- [x] Exportación STEP vía OCCTEngine

## BLOQUEOS

- **Compilación local** — Swift Toolchain no disponible en Windows 11. Workaround: push a GitHub CI.

- [ ] Ejecutar suite de 23 tests en GitHub Actions
- [ ] Validar render loop (paint+sculpt+CAD+animation) en simulador
- [ ] Generar .ipa sin firma para AltStore
- [ ] Beta TestFlight v0.9
