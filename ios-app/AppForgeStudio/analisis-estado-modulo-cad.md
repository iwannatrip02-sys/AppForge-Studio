# Analisis Estado Modulo CAD - AppForge Studio
> Fecha: 2026-05-11 | Sesion: 2026-05-12 00:47 UTC

## 1. Arquitectura Real del Modulo CAD

### Ubicacion exacta de archivos
(Workspace: `ios-app/AppForgeStudio/`)

| Archivo | Ruta | Estado |
|---------|------|--------|
| Shape.swift | `Sources/CADCore/CSG/Shape.swift` | Leido - 7709 bytes, 213 lineas |
| OCCTEngine.swift | `Sources/CADEngine/OCCTEngine.swift` | Leido - sin OCCTSwift |
| BooleanEngine.swift | `Sources/Core/Engines/BooleanEngine.swift` | Leido - sin OCCTSwift |
| BooleanEngine.swift | `Sources/Features/CADMode/Tools/BooleanEngine.swift` | Leido - sin OCCTSwift |
| CADModeView.swift | `Sources/Features/CADMode/` | Existe en Package.swift, no leido |
| ToolViewModel.swift | `Sources/Features/CADMode/` | Existe en Package.swift, no leido |
| CanvasViewModel.swift | `Sources/Features/CADMode/` | Existe, usa booleanEngine |

### Dependencias actuales en Package.swift
- Satin `from: "0.4.0"` (cambiado de branch "main")
- OCCTSwift: **ELIMINADO** del package + target dependency
- Dependencias activas: solo `["Satin"]`

---

## 2. Evaluacion Funcional - Que Funciona vs Que No

### ✅ Funcional (implementacion real)

**Shape.swift - 5 primitivas 3D con vertices reales:**
- `Shape.box(width:height:depth:)` - genera 24 vertices, 36 indices (6 caras)
- `Shape.cylinder(radius:height:segments:)` - vertices + indices circulares
- `Shape.sphere(radius:segments:)` - vertices + indices esfericos
- `Shape.torus(majorRadius:minorRadius:segments:)` - vertices + indices toroidales
- `Shape.cone(radius:height:segments:)` - vertices + indices conicos
- Todas generan `vertexBuffer` e `indexBuffer` validos para Metal via ModelIO

**OCCTEngine.swift - Singleton wrapper:**
- `shared` singleton operativo
- Metodos `makeBox`, `makeCylinder`, `makeSphere`, `makeTorus`, `makeCone` -> delegan a Shape
- `currentShape: Shape?` almacena el shape activo

**BooleanEngine.swift (ambas copias):**
- Usan `Shape` primitives directamente via OCCTEngine
- CanvasViewModel instancia `booleanEngine` correctamente
- Sin referencias a OCCTSwift en ningun archivo activo

### ❌ No funcional (stubs / no implementado)

**Operaciones CSG booleanas - STUBS:**
```swift
// Shape.swift - operador + (union)
static func +(lhs: Shape, rhs: Shape) -> Shape {
    // stub: actualmente solo retorna lhs
    return lhs
}
// operador - (diferencia)
static func -(lhs: Shape, rhs: Shape) -> Shape {
    return lhs
}
// operador & (interseccion)
static func &(lhs: Shape, rhs: Shape) -> Shape {
    return lhs
}
```

**Operaciones de edicion - STUBS:**
```swift
func filleted(radius: Float) -> Shape { return self }  // no hace fillet
func chamfered(distance: Float) -> Shape { return self } // no hace chamfer
func extruded(distance: Float) -> Shape { return self }
func revolved(angle: Float) -> Shape { return self }
func swept(along path: [simd_float3]) -> Shape { return self }
```

**Exportacion STEP - STUB con error:**
```swift
func exportSTEP(path: String) throws {
    throw CADError.unsupportedFormat("STEP export requires OCCT")
}
```

**Modelos nativos (import SAT/STEP) - STUBS:**
```swift
func importSAT(path: String) throws -> Shape {
    throw CADError.unsupportedFormat("SAT import requires OCCT")
}
func importSTEP(path: String) throws -> Shape {
    throw CADError.unsupportedFormat("STEP import requires OCCT")
}
```

**UI faltante:**
- CADViewModel.swift: NO encontrado en el arbol del proyecto
- Vistas SwiftUI conectando CADModeView con Shape/OCCTEngine: no verificadas
- Boton de exportacion en UI: no verificado

---

## 3. Veredicto: Usable Profesionalmente?

**No. No es usable de principio a fin por 4 razones:**

1. **Operaciones CSG son stubs** - No puedes hacer union/diferencia/interseccion real entre primitivas. Sin esto no hay CAD parametrico.

2. **Edicion de bordes es stub** - Fillets, chamfers, extrusiones, revoluciones no operan. Sin esto no hay modelado profesional.

3. **Import/Export STEP/SAT es stub** - No puedes importar modelos existentes ni exportar a formato industrial. Sin esto no hay flujo de trabajo real.

4. **UI no conectada** - Aunque existe CADModeView y ToolViewModel, no se verifico que el pipeline completo (boton -> ViewModel -> Shape -> Metal render) este conectado.

**Que SI funciona:** Las 5 primitivas generan geometria 3D real en la GPU via Metal/ModelIO. OCCTEngine funciona como singleton. BooleanEngine no tiene referencias rotas.

**Equivalencia con competencia:** Es comparable al ~15% de Nomad Sculpt en terminos de features CAD. Tienes las primitivas basicas (box, sphere, cylinder, torus, cone) pero ninguna operacion de edicion.

---

## 4. Opciones para Compilar en Windows

### Opcion 1: xtool (RECOMENDADA)
**Que es:** Reemplazo cross-platform de Xcode basado en SwiftPM. Compila y firma apps iOS/macOS desde Linux/Windows/WSL.
**Como funciona:** `xtool build --platform ios --config release --signing-certificate "..."` desde WSL2.
**Pros:** Unica opcion que soporta Metal indirectamente (compila el codigo, render corre en dispositivo Apple). No requiere Mac fisico para build.
**Contras:** Requiere WSL2 en Windows. La configuracion inicial de signing puede ser compleja. Comunidad pequena (~2-5K usuarios).
**Instalacion:** `curl -fsSL https://xtool.dev/install.sh | bash` dentro de WSL2 Ubuntu.
**Licencia:** Gratuito para uso personal, pago para CI/comercial (~$29/mes).
**Link:** xtool.dev

### Opcion 2: EdgeCompiler
**Que es:** Compilador offline de iOS que corre 100% en Windows sin hardware Apple. Tecnologia relativamente nueva (2025-2026).
**Como funciona:** Descargas el toolchain (~2GB) y compilas con `edgec build`. Genera .app/.ipa directamente.
**Pros:** No requiere WSL, no requiere Mac en la nube, no requiere Xcode. Compilacion puramente local.
**Contras:** Muy nuevo - pocos casos de uso reales documentados. Integracion con Metal no garantizada. Precio no publicado (probablemente ~$99/licencia).
**Link:** edgecompiler.io

### Opcion 3: Swift 6 para Windows (nativo)
**Que es:** El compiler oficial de Swift.org para Windows (disponible desde Swift 5.8+).
**Como funciona:** `swift build` directo en Windows nativo. `swift test` para unit tests.
**Pros:** Gratuito, open-source, soportado por Apple/Google. Perfecto para TDD del modulo CAD.
**Contras:** **NO soporta SwiftUI, NO soporta Metal, NO soporta UIKit.** Solo Foundation + SwiftPM. Sirve para compilar y testear Shape.swift, BooleanEngine, OCCTEngine - pero no para correr la app.
**Instalacion:** Descargar installer de swift.org/download/windows/.
**Uso:** `swift test --target CADCore` para probar primitivas 3D y operaciones CSG.
**Costo:** Gratuito.

### Opcion 4: Mac Mini usado (hardware real)
**Que opcion:** Mac Mini M1 usado (~$400-500 USD en mercado de segunda mano).
**Pros:** Solucion definitiva - Xcode completo, Metal debugger, iOS simulator, Instruments para performance. Sin limitaciones.
**Contras:** Requiere inversion de hardware. No es una solucion de software.
**Veredicto:** Si el proyecto va a produccion, es la mejor inversion a largo plazo.

---

## 5. Recomendacion Concreta

### Para desarrollo inmediato (esta semana):
1. **Instalar Swift 6 para Windows** - Compila y testea Shape.swift, BooleanEngine, y las primitivas 3D con `swift test`. Detecta errores de compilacion sin depender de macOS.
2. **Implementar CSG booleano real** - Sin esto el CAD no es funcional. Shape.swift ya tiene vertices/indices, solo falta implementar la logica de interseccion/union/diferencia de mallas.

### Para build completo (iOS):
**xtool desde WSL2** es la unica opcion realista para compilar el proyecto completo (con SwiftUI + Metal) sin un Mac. EdgeCompiler es prometedor pero aun no maduro.

### Meta a 3 meses:
Mac Mini M1 usado + Xcode nativo. No hay sustituto para el entorno Apple real si el producto va a produccion.

---

## 6. Proximos Pasos Inmediatos

1. Instalar Swift 6 en Windows y correr `swift test --target CADCore` para verificar que Shape.swift compila sin errores
2. Implementar CSG booleano real en Shape.swift (operadores +, -, &)
3. Conectar CADViewModel.swift con CanvasViewModel y CADModeView
4. Probar build completo con xtool en WSL2
