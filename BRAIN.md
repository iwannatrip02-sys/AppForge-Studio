# AppForge Studio — Project Brain
> v73 | Updated: 2026-05-01 07:28 UTC

## ENTIDADES CLAVE
- Satin (tech) — Swift framework for Metal, abstrae shaders y render para iOS 3D graphics. Usado como motor de render.
- Kool (tech) — Kotlin 3D engine for Android usando OpenGL ES. Para version Android futura.
- Assimp (tech) — Libreria C++ open-source para import/export de modelos 3D (STL, OBJ, glTF, FBX).
- ModelIO (tech) — Framework Apple para assets 3D nativos en iOS.
- Blender (tech) — Suite 3D open-source. Su sistema de pintura se analizo para brush logic y shaders.
- Apple Metal (tech) — Framework GPU de bajo nivel de Apple. Base del render de AppForge Studio.
- Shapr3D (competencia) — App CAD parametrico para iPad. Suscripcion $299/ano.
- Nomad Sculpt (competencia) — App escultura 3D para iPad. Pago unico $14.99.
- Feather 3D (competencia) — App modelado 3D para iPad. Suscripcion $9.99/mes.
- Forger (competencia) — App escultura 3D basica para iPad. Pago unico $9.99.
- AppForge Studio (producto) — App iOS con pintura 3D + escultura + CAD + animacion + exportacion a impresion 3D.
- ExportService.swift (modulo) — Servicio de exportacion STL/OBJ/USDZ/STEP/GLTF para impresion 3D.
- ModelCacheService.swift (modulo) — Cache de modelos en memoria (NSCache 50 obj/128MB) + disco (JSON).
- ModelLoadService.swift (modulo) — Servicio de carga de modelos 3D, ahora integrado con ModelCacheService para cache transparente.

## ESTADO ACTUAL
Sprint completado: Fase 5 (Exportacion 5 formatos), Fase 6 (Tests: 12+6+5 tests), Fase 7 (ModelCacheService con memoria+disco), Integracion ModelCacheService+ModelLoadService completa. Proximas mejoras: validar tests en Xcode, modo oscuro completo, pantalla de carga 3D con MTKView+Satin, migracion STEP a OCCTEngine nativo. Resumen de sesion en docs/resumen-sesion-2026-05-01.md y plan en docs/plan-integracion-mejoras.md.

## PRÓXIMAS ACCIONES
1. Validar tests en Xcode (AnimationEngineTests, ExportServiceTests, ModelCacheServiceTests)
2. Modo oscuro completo con DynamicColor + asset catalog
3. Pantalla de carga 3D con MTKView + Satin (progreso real durante loadModel)
4. Migrar STEP Export a OCCTEngine nativo
5. Analisis competitivo vs Shapr3D ($299/ano)
6. Beta testing: AltStore + TestFlight
7. Exportacion FBX y Collada

## PROGRESO FASES
- **Fase 1** (Sistema pinceles 3D): 100%
- **Fase 2** (Escultura v2 con deformers): 100%
- **Fase 3** (Modo CAD con OCCTSwift): 100%
- **Fase 4** (Animacion + Timeline): 100%
- **Fase 5** (Exportacion 5 formatos): 100%
- **Fase 6** (Tests unitarios): 100%
- **Fase 7** (Cache de modelos): 100%
- **Mejoras UI/UX**: En progreso

## DECISIONES RECIENTES
- Integrar ModelCacheService como singleton accesible desde ModelLoadService
- Usar MD5 hash del URL como key de cache unica
- Cache en dos niveles: NSCache (memoria rápida) + JSON en disco (persistencia)
- Limitar NSCache a 50 objetos y 128MB para evitar pressure de memoria
