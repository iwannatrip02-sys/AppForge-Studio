# AppForge Studio — Diseño de Interfaz (canónico)
> 2026-07-07 | Gobierna la Fase B y siguientes. Actualizar aquí ANTES de cambiar UI.
> Catálogo completo de mecánicas (Shapr3D/Nomad desglosados + síntesis y olas):
> **BLUEPRINT_UX_SUPREMACIA.md** — las olas de UI citan secciones de ese doc.

## 1. La tesis

Shapr3D ganó a Fusion360 en iPad no por tener más features sino por una decisión:
**la geometría es el UI**. No hay diálogo de "operación booleana con parámetros":
tocas una cara, arrastras, el sólido cambia. Nomad ganó a ZBrush móvil igual:
el dedo ES el pincel. Fusion360 en cambio arrastra 20 años de menús de escritorio.

AppForge tiene una oportunidad que ninguno de los tres tiene: **un solo modelo
mental para CAD y escultura**. La regla unificadora:

> **Tocar geometría = actuar sobre geometría. Tocar vacío = mover la cámara.**

Ese es el contrato sagrado de toda la app. Cualquier gesto que lo viole es un bug
de diseño aunque compile.

## 2. Anatomía de pantalla (iPad, apaisado)

```
┌──────────────────────────────────────────────────────┐
│ [modo]                viewport 3D              [⚙︎]  │  ← chrome mínimo
│                                                      │
│              LA GEOMETRÍA OCUPA TODO                 │
│                                                      │
│  ┌─ rail de herramientas ─┐                          │  ← izquierda, pulgar izquierdo
│  │ contextual al modo     │                          │
│  └────────────────────────┘                          │
│ [——— barra de parámetros contextual a la tool ———]  │  ← inferior, aparece solo si aplica
└──────────────────────────────────────────────────────┘
```

Principios duros:
- **Chrome ≤ 15% del área**. El viewport nunca se recorta por paneles: los paneles flotan.
- **Nada modal** salvo export/settings. Un diálogo modal en medio del modelado = fallo.
- **Una mano modela, la otra orbita.** Rail a la izquierda (pulgar izq.), gestos de
  cámara con la derecha. Zurdo: espejo en Preferencias.
- **Parámetros junto al efecto**: la barra de push/pull aparece cuando hay cara
  seleccionada, muestra el número EN VIVO y desaparece al aplicar. El usuario nunca
  busca dónde quedó el input.

## 3. Gramática de gestos (contrato)

| Gesto | Sobre geometría | Sobre vacío |
|---|---|---|
| Tap | Seleccionar (cara en CAD, objeto en Select) | Deseleccionar |
| Drag 1 dedo | Acción de la herramienta activa (sculpt stroke, ajustar push/pull) | Orbitar |
| Drag 2 dedos | Pan | Pan |
| Pinch | Zoom | Zoom |
| Doble tap | Encuadrar el objeto | Encuadrar la escena |
| Pencil | SIEMPRE herramienta (presión = intensidad) | Herramienta |

El Apple Pencil nunca orbita: es el instrumento de precisión. Dedo = navegación
por defecto, herramienta si la tool activa lo reclama sobre geometría.

## 4. Estado actual vs. objetivo

**Hecho en Fase B (esta):**
- `SurfaceHit` fluye desde el tap hasta la lógica (posición+normal+modelo REALES;
  antes se pasaba `model.position` — imposible seleccionar caras).
- Pipeline pantalla→rayo→malla→**cara B-rep** (`CameraRay`/`ScenePicker`/`BRepFacePicker`)
  extraído de MetalView, único y cubierto por tests.
- Push/pull interactivo v1: tap-cara → barra con distancia → Añadir/Excavar.
  (v1 usa slider; v2 será drag-sobre-la-cara cuando haya device para calibrar feel.)

**Hecho en Fase D ola 1 (2026-07-08) — la reconexión:**
- El chrome dejó de ser maqueta: `WorkspaceView` ahora monta la vista REAL de cada
  modo (CAD/Sculpt/Paint/Híbrido/Animar/Render). Antes NINGUNA vista de Features/
  se instanciaba: la app mostraba paneles con valores hardcodeados.
- `renderer.setSculptEngine()` por fin se llama (AppState) — el pipeline táctil de
  escultura estuvo muerto desde el origen. 10 deformers seleccionables y sincronizados.
- Router de gestos v1 implementado (deuda #3): drag sobre geometría = herramienta,
  sobre vacío = orbitar, con gate `sculptEnabled` por modo. Deuda #4 cerrada:
  un solo camino de picking (`ScenePicker`); el raycast duplicado de MetalView murió.
- Doble manejo de cámara eliminado (SwiftUI DragGesture vs UIKit pan competían).
- Purga: todo actuador visible tiene efecto real o no se muestra (Loft oculto
  hasta F3; ViewCube ahora orbita/re-encuadra de verdad).

**Deuda de diseño conocida (orden de ataque):**
1. Drag-en-cara para push/pull en vivo (necesita device; el controller ya separa
   selección de aplicación para enchufarle preview).
2. El router de drag aplica a sculpt; extenderlo a CAD (drag-en-cara = push/pull
   cuando haya herramienta activa) tras calibrar en device.
3. Timeline paramétrico (cadHistory) como tira horizontal inferior colapsable,
   estilo Fusion360 pero táctil: cada op es un chip; tap = inspeccionar, drag = reordenar.
4. Rediseño del chrome de CADModeView según §2 (hoy son barras horizontales
   apiladas arriba, estilo escritorio; objetivo: rail izquierdo + barras efímeras).
5. Pintura real (F3): BrushEngine fue eliminado; strokes existen pero no proyectan
   color sobre la malla. Los controles de pintura visibles son mínimos a propósito.

## 5. Reglas para agentes que toquen UI

- Antes de añadir un botón: ¿puede ser un gesto sobre la geometría? Si sí, gesto.
- Antes de añadir un panel: ¿puede ser una barra contextual efímera? Si sí, barra.
- Todo actuador nuevo pasa por `HapticService` (light=select, medium=apply, heavy=destroy).
- Textos de estado en español, cortos, en `statusMessage` de su controller — la UI
  los muestra, los tests los verifican.
- Nada de `DispatchQueue` en vistas: los controllers (@MainActor ObservableObject)
  son los dueños del estado; las vistas solo bindean.
