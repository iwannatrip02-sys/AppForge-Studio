# AppForge Studio - TODO.md
> Estado: 2026-05-01 07:28 UTC

- [x] Transiciones animadas entre modos (matchedGeometryEffect + .opacity + .slide)
- [x] Haptics en ToolbarView (UIImpactFeedbackGenerator en Snap, Reset, Brush, Loop, Delete)
- [x] Namespaces por pagina en OnboardingView (page0NS..page4NS separados)
- [x] AnimationEngine.moveKeyframe(id:to:) para mover keyframes en el timeline
- [x] CI/CD pipeline: GitHub Actions workflow (macos-14, Xcode 16.1, iPad Pro 11 M4)
- [x] AltStore deploy: scripts/deploy-altstore.sh + scripts/export-options.plist
- [x] AnimationEngine conectado con SatinRenderer: evaluate(at:) + deltaTime + transforms
- [x] Fase 5: Exportacion 5 formatos (OBJ, STL, USDZ, STEP, GLTF)
- [x] Fase 6: Tests (AnimationEngineTests 12, ExportServiceTests 6, ModelCacheServiceTests 5)
- [x] Fase 7: ModelCacheService (NSCache 50 obj/128MB + disco JSON)
- [x] Integrar ModelCacheService con ModelLoadService (cache transparente)

- [ ] Validar tests en Xcode (compilar y ejecutar)
- [ ] Modo oscuro completo (DynamicColor + asset catalog)
- [ ] Migrar STEP Export a OCCTEngine nativo
- [ ] Pantalla de carga 3D con MTKView + Satin
- [ ] Analisis competitivo vs Shapr3D ($299/ano)
- [ ] Beta testing: AltStore + TestFlight
- [ ] Exportacion FBX y Collada
- [ ] Refactor GeometryConstraintManager para constraints parametricos
- [ ] Agregar undo/redo con CADHistoryTree
- [ ] Implementar Material Editor con PBR textures
- [ ] Animacion de morph targets entre mallas
- [ ] Exportar a USDZ para AR QuickLook
> Updated: 2026-05-01 07:28 UTC

## Foco actual
- Validar tests en Xcode (AnimationEngineTests, ExportServiceTests, ModelCacheServiceTests)
- Modo oscuro completo
- Pantalla de carga 3D con MTKView + Satin

## Bloqueos
(ninguno)

## Completados
- Fase 5: Exportacion 5 formatos con ExportView y Confetti *(done 2026-05-01)*
- Fase 6: Tests unitarios para AnimationEngine, ExportService, ModelCacheService *(done 2026-05-01)*
- Fase 7: ModelCacheService con memoria + disco *(done 2026-05-01)*
- Integrar ModelCacheService con ModelLoadService *(done 2026-05-01)*
