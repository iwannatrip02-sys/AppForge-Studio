# AppForge Studio - Project Brain
> Estado vivo del proyecto. Reescrito post-sesion por Gotchi.
> Updated: 2026-04-29 15:22 UTC

## ENTIDADES CLAVE
- Satin (tech) - Swift framework for Metal, abstrae shaders y render para iOS 3D graphics. Usado como motor de render.
- OCCTSwift (tech) - Swift bindings para Open CASCADE Technology. Proporciona operaciones CAD booleanas, fillet, chamfer, shell, extrude, revolve, loft, sweep, sketch 2D, export STEP/STL. OCCTEngine.swift es singleton con API completa.
- ModelIO (tech) - Framework Apple para assets 3D nativos en iOS. Usado por ExportService y BooleanEngine CSG.
- Blender (tech) - Suite 3D open-source. Su sistema de pintura se analizo para brush logic y shaders. Clones eliminados (~3GB).
- Apple Metal (tech) - Framework GPU de bajo nivel de Apple. Base del render de AppForge Studio.
- Shapr3D (competencia) - App CAD parametrico para iPad. Suscripcion $299/ano. Objetivo a superar.
- Nomad Sculpt (competencia) - App escultura 3D para iPad. Pago unico $14.99.
- Feather 3D (competencia) - App modelado 3D para iPad. Suscripcion $9.99/mes.
- Forger (competencia) - App escultura 3D basica para iPad. Pago unico $9.99.
- AppForge Studio (producto) - App iOS con pintura 3D + escultura + CAD + animacion + exportacion a impresion 3D.
- ExportService.swift (modulo) - Servicio de exportacion STL/OBJ/STEP/USDZ via ModelIO + OCCTEngine. Reescrito en Fase 4D.
- AnimationEngine.swift (modulo) - Motor de animacion inout corregido, clip management, timeline, keyframes interpolados. Modificado: sistema keyframes (addKeyframe, removeKeyframe, keyframeTypes).
- SubdivisionEngine.swift (modulo) - Subdivision Catmull-Clark con slider preview.
- BooleanEngine.swift (modulo) - CSG booleano implementado con ModelIO (union, difference, intersection). Bug auto-union corregido.
- OnboardingView.swift (modulo) - NUEVO: tutorial de 3 paginas con persistencia UserDefaults.
- TimelineView.swift (modulo) - REESCRITO: AddKeyframeSheet, lista keyframes con swipe to delete.

## ESTADO ACTUAL
Fase 4 completada (animacion keyframes + onboarding + pipeline CI/CD). Workflow build-ios.yml creado en .github/workflows/. Pipeline: push a main -> GitHub Actions (macos-14) -> compila .ipa sin firma. Pendiente: push a main para probar build + AltStore en iPad.

Fase 4D completada. 3 archivos reescritos/actualizados:
- ExportService.swift: exportToSTEP, exportToUSDZ agregados, meshToMDL mejorado, manejo de errores
- ExportViewModel.swift: enum con 4 formatos (OBJ, STL, STEP, USDZ), iconos SF Symbols
- ExportView.swift: LazyVGrid visual, ProgressView, fileExporter con ExportFileData

## PROXIMAS ACCIONES
1. Publicar repo en GitHub y push a main para triggerear build
2. Instalar AltStore en iPad (AltServer desde Windows)
3. Cargar .ipa compilado via AltStore
4. Probar flujo completo: CAD -> escultura -> pintura -> animacion -> exportacion STL