# Feedback de device (iPad real) — 2026-07-08, beta-2026-07-08
> Fuente: prueba en vivo del usuario. Este doc alimenta el backlog de beta.
> Orden = impacto sobre percepción. NO cerrar sin verificar en device.

## P0 — BLOQUEADOR
- [x] **Viewport negro en TODOS los modos** (los objetos se crean — aparecen en
  historial — pero nada se ve). CAUSA RAÍZ encontrada: la cámara de scene3D jamás
  llegaba a la GPU (PerspectiveCamera de Satin congelada del init). Fix + blindaje
  CameraMatrixTests. **VERIFICAR EN DEVICE con la próxima IPA.**

## P1 — Rotos o engañosos (el usuario los vio)
- [ ] **Historial CAD: selección y borrado mal.** Creó caja+esfera+cilindro+cilindro+cono:
  solo el último aparece seleccionable; "borrar" elimina TODO en vez del paso tocado.
- [ ] **Sketch inutilizable para el objetivo** (el corazón Shapr3D): el trazo no se ve
  en tiempo real; no se crean regiones cerradas seleccionables; no se pueden
  seleccionar líneas/caras para extruir. → BLUEPRINT S4 (ola Sketch mágico) SUBE de
  prioridad: es "el problema del 3D en iPad" que la app promete resolver.
- [ ] Pencil: sensibilidad OK, pero la experiencia de dibujo es rara/no en vivo.

## P2 — Estructura de app que falta (se siente incompleta)
- [ ] **Sin página de inicio / gestión de proyectos** (crear/abrir/duplicar/borrar
  documentos). Hoy la app abre directo a una escena única sin persistencia visible.
- [ ] **Sin apartado de Configuración** (preferencias, zurdo/diestro, unidades).
- [ ] **Export pobre**: pantalla de exportación percibida como mala; sin detalle
  por formato ni feedback claro.
- [ ] Render y Animación sin "detalle" — se sienten placeholder.
- [ ] **Historial como panel lateral plegable estilo Shapr3D** (hoy: tab que sustituye
  el viewport — malo).

## P3 — Estética (mejoró mucho, pero)
- [ ] Iconos/textos demasiado pequeños en varias zonas (historial CAD citado).
  Revisar tamaños mínimos táctiles (44pt) y tipografía ≥10-11pt en controles.
- [ ] Percepción general: "todo un poco disperso" — consolidar chrome (rail lateral).

## Positivo confirmado
- La estética general mejoró mucho ("mucho más bonita").
- Sensibilidad del Pencil: buena, natural.
- Chrome/botones/deslizables responden ("casi todo accedo y funciona").

## Segunda prueba (misma fecha, beta-2026-07-08b) — fix de cámara NO fue suficiente
- [ ] **El visor 3D sigue negro** (solo el visor; el chrome funciona). → Diagnóstico
  definitivo desplegado: triángulo de sanidad compilado desde fuente en runtime +
  HUD en pantalla (renderCalls/encodedFrames/pipelines/renderables/cámara/error GPU).
  La próxima prueba del usuario ES el bug report.

## Backlog de producto ampliado (visión del usuario, priorizar tras el visor)
- Sketch de grado profesional CAD: trazo en tiempo real, radios, círculo/rect/arco
  reales, regiones cerradas seleccionables/extruibles, constraints visibles.
- Selección plena: puntos/líneas/caras/objetos; proyectar curvas sobre superficies;
  extraer líneas/puntos/caras; duplicar/rotar/deformar.
- Transformaciones con gizmo pro: gizmos GLOBALES y LOCALES (mundo vs objeto).
- Sculpt nivel Nomad: pinceles con MINIATURA de su efecto, velocidad, pestañas
  bien orientadas; esfera inicial en modo sculpt.
- Pintura: pinceles/brochas reales (hoy no hay nada) — F3.
- Capas y sistema de archivos/jerarquía de escena bien organizados.
- Undo/redo confiable en TODO (usuario: "no funciona en nada").
- Export detallado por formato + **AR Quick Look clave**: materiales realistas que
  respondan a la iluminación REAL de la escena (USDZ con PBR bien mapeado).
- Materiales e iluminación (pensar desde ya para render).
- **FUTURE (v1.5+): slicer de impresión 3D integrado o export perfecto a slicers
  de iPad — "la app todo-en-uno del 3D".**
- Unión CAD↔Sculpt: la respuesta de diseño es Forge Flow (BLUEPRINT §3.2, hornear
  B-rep→malla con badge de material y regla de oro del router). Plan B aceptado por
  el usuario: flujos separados que convergen en export. V1: Forge Flow simple.
