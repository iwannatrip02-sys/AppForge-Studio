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
