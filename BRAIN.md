# AppForge Studio — Project Brain
> v74 | Updated: 2026-05-01 07:30 UTC

## ENTIDADES CLAVE
- Satin (tech) — Swift framework for Metal, abstrae shaders y render para iOS 3D graphics.
- Kool (tech) — Kotlin 3D engine for Android usando OpenGL ES.
- Assimp (tech) — Libreria C++ open-source para import/export de modelos 3D (STL, OBJ, glTF, FBX).
- ModelIO (tech) — Framework Apple para assets 3D nativos en iOS.
- Blender (tech) — Suite 3D open-source. Su sistema de pintura se analizo para brush logic y shaders.
- Apple Metal (tech) — Framework GPU de bajo nivel de Apple.
- Shapr3D (competencia) — App CAD parametrico para iPad. Suscripcion $299/ano.
- Nomad Sculpt (competencia) — App escultura 3D para iPad. Pago unico $14.99.
- Feather 3D (competencia) — App modelado 3D para iPad. Suscripcion $9.99/mes.
- Forger (competencia) — App escultura 3D basica para iPad. Pago unico $9.99.
- AppForge Studio (producto) — App iOS con pintura 3D + escultura + CAD + animacion + exportacion a impresion 3D.
- ThemeManager + AppTheme (sistema) — Modo oscuro completo con semantic colors para 11+ vistas.
- LoadingScreenView (componente) — Pantalla de carga 3D con MTKView + ProgressView SwiftUI.

## ESTADO ACTUAL
Modo oscuro completo implementado con ThemeManager+AppTheme, integrado en AppForgeStudioApp via AppRootView. Pantalla de carga 3D (LoadingScreenView) creada con MTKView de fondo + overlay SwiftUI. Commit e7acae5 pusheado a GitHub (67 archivos, 4737 inserciones). Proximo foco: migrar STEP Export de ModelIO a OCCTEngine nativo para mayor fidelidad.

## PRÓXIMAS ACCIONES
1. Migrar STEP Export a OCCTEngine nativo
2. Validar tests en Xcode (AnimationEngineTests, ExportServiceTests, ModelCacheServiceTests)
3. Analisis competitivo vs Shapr3D ($299/ano)
4. Beta testing: AltStore + TestFlight
5. Exportacion FBX y Collada

## PROGRESO FASES
- **Fase 1** (Sistema pinceles 3D): 100%
- **Fase 2** (Escultura v2 con deformers): 100%
- **Fase 3** (Modo CAD con OCCTSwift): 100%
- **Fase 4** (Animacion + Timeline): 100%
- **Fase 5** (Exportacion 5 formatos): 100%
- **Fase 6** (Tests unitarios): 100%
- **Fase 7** (Cache de modelos): 100%
- **Mejoras UI/UX**: 90% (modo oscuro completo, pantalla de carga 3D)

## DECISIONES RECIENTES
- Usar ThemeManager como @EnvironmentObject para acceso global al tema
- AppTheme con propiedades semanticas: background, surface, surfaceSecondary, textPrimary, textSecondary
- LoadingScreenView con MTKView de fondo + ProgressView + LinearProgressView overlay
- preferredColorScheme(.dark/.light) reactivo a appState.isDarkMode
