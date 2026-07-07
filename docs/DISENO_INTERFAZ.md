# AppForge Studio — Diseño de Interfaz (canónico)
> 2026-07-07 | Gobierna la Fase B y siguientes. Actualizar aquí ANTES de cambiar UI.

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

**Deuda de diseño conocida (orden de ataque):**
1. **Highlight de la cara seleccionada** en el render (overlay del triángulo-grupo de la
   cara; requiere pasar face→triángulos del bridge OCCT). Sin feedback visual, la
   selección es a ciegas — es la próxima pieza de UI, no negociable.
2. Drag-en-cara para push/pull en vivo (necesita device; el controller ya separa
   selección de aplicación para enchufarle preview).
3. El drag de 1 dedo hoy siempre orbita; falta el router "¿empezó sobre geometría?"
   (un hitTest al inicio del gesto decide orbit vs tool — la infraestructura ya existe).
4. Sculpt: `raycastForSculpt` vive en MetalView y funciona; migrarlo a `ScenePicker`
   para un solo camino de picking.
5. Timeline paramétrico (cadHistory) como tira horizontal inferior colapsable,
   estilo Fusion360 pero táctil: cada op es un chip; tap = inspeccionar, drag = reordenar.

## 5. Reglas para agentes que toquen UI

- Antes de añadir un botón: ¿puede ser un gesto sobre la geometría? Si sí, gesto.
- Antes de añadir un panel: ¿puede ser una barra contextual efímera? Si sí, barra.
- Todo actuador nuevo pasa por `HapticService` (light=select, medium=apply, heavy=destroy).
- Textos de estado en español, cortos, en `statusMessage` de su controller — la UI
  los muestra, los tests los verifican.
- Nada de `DispatchQueue` en vistas: los controllers (@MainActor ObservableObject)
  son los dueños del estado; las vistas solo bindean.
