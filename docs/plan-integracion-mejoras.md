# Plan de Integracion y Mejoras - AppForge Studio
> 2026-05-01 02:25 UTC

## Avances de Esta Sesion

### Fase 5: Exportacion (COMPLETA)
- ExportService.swift: 144 lineas, 5 formatos (OBJ, STL, USDZ, STEP, GLTF)
- ExportView en Features/ExportMode/ con CircularProgressView y ConfettiView
- TestCube.swift: modelo de prueba 8 vertices, 12 triangulos

### Fase 6: Tests (COMPLETA)
- AnimationEngineTests.swift: 12 tests
- ExportServiceTests.swift: 6 tests (5 formatos + modelo vacio)
- Tests/ directorio creado en ios-app/AppForgeStudio/Tests/

### Fase 7: Performance (COMPLETA)
- ModelCacheService.swift: 201 lineas, NSCache 50 obj/128MB + disco JSON
- ModelCacheServiceTests.swift: 5 tests

### Fase 8: UX (PREEXISTENTE)
- OnboardingView con matchedGeometryEffect
- ToolbarView con tooltips y haptics
- ExportView con confetti animado y selector de formatos

## Integracion ModelCacheService <> ModelLoadService

### Estado Actual
- ModelLoadService carga modelos con MDLAsset sin cache
- ModelCacheService tiene memoria (NSCache) + disco, pero no esta conectado

### Plan de Integracion
1. Agregar propiedad `cacheService: ModelCacheService` a ModelLoadService
2. En `loadModel(url:)`: check cache primero, si miss -> carga normal y guarda en cache
3. En `createPrimitive(type:)`: no cachear primitivas (son generadas, no de archivo)
4. Cache key = URL absoluta

## Mejoras Propuestas

### Prioridad Alta
1. **Modo oscuro completo** (DynamicColor + asset catalog)
   - Implementar DynamicColor en AppState
   - Assets en catalog para light/dark
   - Aplicar en todas las vistas

2. **Correr tests en Xcode**
   - Validar compilacion de AnimationEngineTests, ExportServiceTests, ModelCacheServiceTests
   - Asegurar que los mocks funcionan sin GPU

3. **Integrar ModelCacheService con ModelLoadService**
   - Cache transparente: loadModel(url:) primero cache, luego disco, luego MDLAsset

### Prioridad Media
4. **Exportacion FBX y Collada**
   - ModelIO soporta export a varios formatos
   - Agregar al ExportService y ExportView

5. **Pantalla de carga 3D**
   - MTKView + Satin con progreso real durante loadModel()

6. **Analisis competitivo vs Shapr3D**
   - Documentar $299/ano vs modelo de pago unico de AppForge

## Proximos Pasos
1. Modificar ModelLoadService para inyectar ModelCacheService
2. Implementar cache check en loadModel(url:)
3. Agregar modo oscuro con DynamicColor
4. Validar tests en Xcode
5. Actualizar GOTCHI.md/BRAIN.md/TODO.md/DECISIONS.md con estado actual
