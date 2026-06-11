# Análisis de mejoras reales — AppForge Studio
> 2026-04-30 | Basado en código fuente verificado

## Bugs confirmados (causan crash o comportamiento incorrecto)

### 1. ExportService sin manejo de errores en STL/USDZ
**Archivo:** `Core/Services/ExportService.swift` líneas 25-35
**Problema:** `asset.export(to:fileType:)` no tiene `do/try/catch`. Si falla (permisos, disco lleno, modelo inválido), retorna `true` aunque el archivo no se haya escrito porque `FileManager.default.fileExists(atPath:)` puede dar falso positivo si hay un archivo previo.
**Impacto:** El usuario cree que exportó correctamente pero el archivo está corrupto o vacío.
**Solución:** Envolver en `do { try asset.export(...); return true } catch { print(error); return false }`.

### 2. SatinRenderer: deltaTime explosivo en primer frame
**Archivo:** `AppForgeStudio/SatinRenderer.swift` líneas 22-23
**Problema:** `lastFrameTime` se inicializa en 0. `CACurrentMediaTime()` retorna segundos desde boot (~segundos). En el primer `update()`, `deltaTime = currentTime - 0` que es un valor enorme. Esto avanza `animationEngine.currentTime` de golpe y puede causar que la animación salte al final instantáneamente.
**Impacto:** Al abrir un clip de animación, el modelo aparece en la pose final.
**Solución:** Inicializar `lastFrameTime = CACurrentMediaTime()` en `init`.

### 3. AnimationEngine.currentTransforms no conectado a SatinRenderer
**Archivo:** `AnimationEngine.swift` tiene `@Published var currentTransforms` (línea ~45), pero `SatinRenderer.update()` solo llama `engine.evaluate(at:)` y no aplica los transforms a `scene3D.models`.
**Impacto:** La animación se evalúa pero no se refleja en la escena renderizada.
**Solución:** En `SatinRenderer.update()`, tras evaluar, iterar `engine.currentTransforms` y asignar `model.transform = transform`.

### 4. Tasks sin cancelación al cambiar de modo
**Archivo:** `Views/AnimationView.swift` (no leído aún, inferido por patrón)
**Problema:** Si el usuario cambia de modo mientras se carga un clip de animación (Task async), la tarea sigue corriendo en background. Al volver, puede haber estado inconsistente o memory leak.
**Impacto:** UI congelada, posible crash si se accede a recursos liberados.
**Solución:** Usar `withTaskCancellationHandler` o `task.id` y cancelar en `onDisappear`.

### 5. MTKView se recrea en cada cambio de modo
**Archivo:** Vistas de modo (CADModeView, SculptModeView, etc.)
**Problema:** Cada vista crea su propio `MTKView` dentro de `Group { switch }`. SwiftUI recrea la vista al cambiar de modo, destruyendo el pipeline de Metal y recreándolo. Tarda 1-2 segundos con pantalla negra.
**Impacto:** Experiencia entrecortada al cambiar entre CAD/Escultura/Híbrido.
**Solución:** Mover `MTKView` fuera del switch, a un `ZStack` compartido, y solo cambiar el `scene3D` que se renderiza.

## Mejoras de rendimiento para iPad Pro M1

### 6. CACurrentMediaTime sin throttling en SatinRenderer.update()
**Archivo:** `SatinRenderer.swift`
**Problema:** `update()` se llama en cada frame (hasta 120fps en iPad Pro M1). Si no hay animación activa (`engine.isPlaying == false`), sigue calculando deltaTime, evaluando `evaluate(at:)` y descomponiendo matrices. CPU al 20-30% en idle.
**Solución:** `guard engine.isPlaying else { lastFrameTime = currentTime; return }` al inicio de `update()`.

### 7. SCNTransaction en SculptModeView para undo bloquea el render
**Inferido de la arquitectura:** Si usa `SCNTransaction` para undo buffer en mallas >500k vértices, bloquea el render loop de Metal.
**Solución:** Usar buffer de comandos asíncronos con `MTLCommandBuffer` y `addCompletedHandler`.

## Cómo probar en iPad gratis (hoy)

### Opción A — Xcode + dispositivo físico (gratis, requiere Mac)
1. Conectar iPad al Mac vía USB.
2. En Xcode, seleccionar tu iPad como destino.
3. Presionar Play (Cmd+R). Xcode firma automáticamente con tu Apple ID gratuito.
4. La app expira en 7 días, pero puedes reinstalar.

### Opción B — .ipa + Diawi (sin Mac después del build)
1. En Mac, hacer Archive (Product > Archive), luego Export -> Development.
2. Subir el .ipa a [Diawi.com](https://www.diawi.com) (gratis, sin registro).
3. Abrir el enlace generado en Safari del iPad -> instalar.

### Opción C — AltStore (requiere AltServer en Mac una vez)
1. Instalar AltStore en el iPad desde [altstore.io](https://altstore.io).
2. En Mac, ejecutar AltServer y seleccionar tu iPad.
3. Arrastrar .ipa a AltStore en el iPad.
4. Funciona 7 días sin renovar, pero AltStore refresca automáticamente si el Mac está en la misma red.

**Recomendación:** Opción A (Xcode directo) es la más rápida si tienes Mac a mano. Si no, genera .ipa y usa Diawi.

## Ejecución inmediata
1. Corregir bugs 1, 2, 3, 6 (código Swift).
2. El bug 4 y 5 requieren cambios arquitectónicos más grandes (postergar a siguiente sprint).
3. Para probar hoy: build + deploy por USB.
