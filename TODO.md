# AppForge Studio - TODO.md
> Estado: 2026-05-01 07:30 UTC

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
- [x] Modo oscuro completo (ThemeManager + AppTheme + 11 vistas actualizadas)
- [x] Pantalla de carga 3D (LoadingScreenView con MTKView + ProgressView)

- [ ] Validar tests en Xcode (compilar y ejecutar)
- [ ] Migrar STEP Export a OCCTEngine nativo
- [ ] Analisis competitivo vs Shapr3D ($299/ano)
- [ ] Beta testing: AltStore + TestFlight
- [ ] Exportacion FBX y Collada
- [ ] Refactor GeometryConstraintManager para constraints parametricos
- [ ] Agregar undo/redo con CADHistoryTree
- [ ] Implementar Material Editor con PBR textures
- [ ] Animacion de morph targets entre mallas
- [ ] Exportar a USDZ para AR QuickLook
> Updated: 2026-05-01 08:26 UTC

## Foco actual
- Migrar STEP Export a OCCTEngine nativo
- Validar tests en Xcode

## Pendientes
- Migrar STEP Export a OCCTEngine nativo

## Bloqueos

## Completados recientes
- Modo oscuro completo con ThemeManager + AppTheme + 11+ vistas *(commit e7acae5)*
- Pantalla de carga 3D con MTKView + SwiftUI overlay *(commit e7acae5)*

## Completados
(ninguno)
