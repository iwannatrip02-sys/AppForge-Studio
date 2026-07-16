# FASE 1 — DIBUJO PROFESIONAL (contrato)

**Objetivo:** el bloque de dibujo completo al nivel de Shapr3D — herramientas, mecánicas, snap, selección, preview en vivo, visualización y estética de esta parte. Es UN solo bloque funcional: del dibujo nace el CAD, no de las primitivas.

**Regla de done:** un ítem está hecho cuando el usuario lo verifica funcionando en el iPad. CI verde solo sirve para generar el IPA. Ningún ítem se marca por tests.

**Regla de ejecución:** cero trabajo de CI/probe/documentos nuevos. Este documento es el único plan de la fase.

---

## 1. Kernel de sketch (fundación)

- [ ] Topología conectada real: una esquina = UN punto compartido entre curvas. Perfiles y regiones cerradas derivan de la topología, no de heurísticas de distancia.
- [ ] Un solo sistema de sketch: hoy existen dos (`CADSketchEngine` + `SketchController`). Queda uno.
- [ ] Eliminar el encadenado automático de línea entre los dos últimos puntos añadidos (raíz de "encadena líneas encima de la figura").

## 2. Snap e inferencia (transversal a TODAS las herramientas)

- [ ] Snap a: extremos, puntos medios, centros (círculo/arco/rectángulo/cara), cuadrantes, intersecciones, sobre-curva, rejilla.
- [ ] Guías de inferencia en vivo mientras se dibuja: horizontal/vertical, extensión de línea, perpendicular, tangente, alineación con puntos existentes (líneas punteadas como Shapr3D).
- [ ] Feedback al engancharse: resalte visual + háptico. Radio de snap adaptativo al zoom; con Pencil radio menor (más precisión).
- [ ] **Caso de aceptación:** hacer un hueco exactamente centrado en la cara de un cubo, al primer intento, sin pelear.

## 3. Herramientas (cada una completa: crear + editar + snap + entrada numérica)

Primera ola:
- [ ] **Línea**: encadenada por segmentos; H/V automático con guía; entrada numérica de longitud/ángulo mientras se dibuja; arco tangente desde el extremo (mecánica Shapr3D).
- [ ] **Círculo**: centro-radio, dimensión editable en pantalla.
- [ ] **Rectángulo**: esquina-esquina y desde centro; las 4 esquinas arrastrables después.
- [ ] **Arco**: dos modos — 3 puntos y centro-inicio-fin; extremos y radio editables con gizmos.
- [ ] **Spline**: DOS modos como Shapr3D — por puntos de paso (interpolada) y por puntos de control; puntos editables después. La actual no funciona y no tiene modelo de datos detrás.

Segunda ola (dentro de la fase, tras verificar la primera):
- [ ] Elipse y polígono.
- [ ] Trim / Split / Offset / Mirror.

## 4. Selección (dedo y Pencil por igual)

- [ ] Tap sobre un trazo → lo selecciona (tolerancia generosa con dedo, fina con Pencil).
- [ ] Doble tap → selecciona la cadena/perfil completo.
- [ ] Tap sobre un punto → lo selecciona; arrastrarlo lo mueve con snap.
- [ ] Tap en región cerrada → la selecciona (se ve sombreada = extruible).
- [ ] Tap en vacío → deselecciona todo.
- [ ] Los dibujos ya dibujados siempre son seleccionables y editables — con dedo o con Pencil.

## 5. Preview en vivo

- [ ] Drag desde región cerrada → extrusión con la geometría siguiendo el dedo de forma CONTINUA (transición visible, no salto de estados).
- [ ] El mismo principio para toda operación con drag de esta fase: lo que se arrastra se ve transformándose en tiempo real según la medida.

## 6. Visualización y estética (FORGE GLASS aplicado de verdad a esta parte)

- [ ] Grosor de líneas y aristas nítido y adaptativo al zoom (reportado: aristas demasiado delgadas).
- [ ] Estados visuales claros: normal / seleccionado / bajo el dedo / snap activo — con los colores del Design Bible, no los actuales.
- [ ] Puntos visibles y tocables (hit de ~44pt aunque se dibujen pequeños).
- [ ] Regiones cerradas sombreadas (señal de "esto se puede extruir").
- [ ] Gizmos rediseñados: SIEMPRE visibles por encima del objeto (hoy el propio objeto 3D los tapa), colores/formas del Design Bible, tamaño adaptativo al zoom.
- [ ] Toolbar de sketch reorganizada: fuera las herramientas "por allá arriba"; barra contextual estilo Shapr3D.

## 7. Integración con el 3D

- [ ] El sketch vive en un plano; dibujar sobre la cara de un sólido crea el sketch en esa cara.
- [ ] La extrusión desde región genera B-rep real (camino existente de `SketchController`).
- [ ] Undo/redo cubre todo lo anterior.

---

## Orden de construcción

1. Kernel + motor de snap (fundación de todo lo demás)
2. Línea, círculo, rectángulo, arco sobre el kernel nuevo
3. Selección completa
4. Spline (2 modos)
5. Preview vivo de extrusión desde región
6. Visualización + estética + toolbar
7. Segunda ola de herramientas

Cada entrega al iPad lleva una lista corta de qué probar. Si el usuario no lo percibe funcionando, se reabre y no se avanza.

## Estado actual auditado (2026-07-16, por qué se reescribe)

- `addPoint` crea una línea automática entre los dos últimos puntos SIEMPRE → dibujos ensuciados.
- El único snap existente es a rejilla. No hay extremos, centros, intersecciones ni guías.
- La herramienta Spline del toolbar no tiene NINGUNA implementación detrás (botón falso).
- `splitToLines` duplica los puntos de cada segmento → nada queda conectado topológicamente → regiones y selección imposibles de forma robusta.
- No existe hit-testing de entidades de sketch: la selección de dibujos nunca ha podido funcionar.
- Hay dos sistemas de sketch paralelos otra vez (`CADSketchEngine` y `SketchController`).
