# AppForge Studio — TODO.md
> Updated: 2026-07-08
> CI VERDE: build + 205 tests (0 fallos) + IPA. Rama feature/fase-c (PR #9), adelantada a main.

## Foco actual
- FASE A COMPLETA (2026-07-07, PR #7): núcleo B-rep fuente de verdad — Model.cadShape,
  booleanos OCCT reales entre modelos, push/pull por cara (BRepFeat boss/pocket),
  fillet/chamfer/shell B-rep in-place, STEP AP214 real. 179 tests verdes con
  oráculos de volumen exactos.
- FASE B COMPLETA (2026-07-07, PR #8): manipulación directa — pipeline
  pantalla→rayo→malla→cara B-rep (ScenePicking, testeable), bug onTouch3D
  (pasaba model.position), PushPullController + herramienta Push/Pull con barra
  contextual, docs/DISENO_INTERFAZ.md canónico. 190 tests verdes.
- FASE C EN CURSO (rama feature/fase-c, PR #9, 206 tests verdes 2026-07-08):
  - [x] Highlight visual de cara seleccionada (overlay __faceHighlight amarillo,
    BRepFacePicker.highlightMesh) + undo/redo B-rep (BRepHistory) + overlays no-tocables.
    BUG corregido: Fatal access conflict en BRepHistory.swapTop (syncCounts en defer
    leía los arrays inout prestados) — solo verificable por CI, crasheaba 4 tests.
  - [x] Drawings 2D DXF+PDF (DrawingExportService): proyecta el B-rep a vistas ortográficas
    (planta/alzado/lateral/iso) → DXF R12 (Exporter.writeDXF) y PDF imprimible A4/A3
    (Exporter.writePDF). Shapr3D cobra esto.
  - [x] Feature Recognition (FeatureRecognitionService): agujeros + cajeras desde el
    B-rep vía AAG (shape.buildAAG → detectPockets/detectHoles). Base para selección
    inteligente y árbol de features.
  - [ ] Siguiente: UI para Drawings/Features (barra export DXF + resaltar features);
    drag-en-cara para push/pull en vivo (necesita device); router de gesto CAD
    geometría-vs-vacío (la lógica ya existe para sculpt en MetalView.handlePan);
    PDF export (OCCTSwift trae PDFExporter), SheetMetal (kernel listo).
- Bajar la IPA sin firmar del CI y sideload para probar en iPad real

## Pendientes
- [x] CI compila sin errores *(done 2026-07-07 — 20 olas, ~60 errores)*
- [x] Tests pasan en iOS Simulator via CI *(done 2026-07-07 — 165/165)*
- [ ] Obtener cuenta Apple Developer ($99/año) para firmar y deployar
- [ ] O conseguir Mac/Mac mini para compilar + sideloading gratuito (AltStore, 7 días)
- [x] Agregar botón "Import" con fileImporter → ModelLoadService *(done 2026-07-08, ola 1C beta: ExportView, security-scoped, OBJ/STL/GLTF/FBX/USDZ)*
- [x] Arreglar export GLTF *(FANTASMA — el .bin sí se escribía; test fuerte añadido 2026-07-08)*
- [x] BUG1/BUG2/BUG5 render *(auditoría 2026-07-08: los 3 YA estaban resueltos en código; NormalMatrixTests añadido como blindaje — ver BRAIN.md)*
- [x] BUG3 UInt16→UInt32, BUG7 grab, BUG9 rebuild *(corregidos pre-F0/F0)*
- [ ] Conectar sculpt al touch — VERIFICAR (MetalView.handlePan tiene path de sculpt con raycast; auditar si los 10 deformers reciben strokes de verdad)
- [ ] Activar botones de HybridMode — Remesh, Color, Tamaño, Opacidad, Loop Cut, Bisel (engines implementados, closures vacíos)
- [ ] Implementar filleted/chamfered/shelled/extruded/revolved/swept reales en Shape BSP legacy (stubs identidad) — o retirar el path legacy (el real es B-rep vía BRepModeling)
- Actualizar GOTCHI.md: Stack local dice Satin 0.3.0 pero Package.swift usa 13.0.0
- Resolver Hi-Rez-Satin/ untracked: es symlink roto, submodule, o archivo corrupto?

## Bloqueos
- Sin Mac para compilar localmente (Windows 11)
- Sin Apple Developer account para firmar/deployar
- Satin repo archivado (Hi-Rez/Satin, último tag 13.0.0, Abril 2025)

## Completados
- BUG6 (Shape.swift/Mesh.swift): dual Mesh/Vertex definitions — UNIFICADO a Mesh.swift *(done 2026-05-26)*
- BUG2 (Shape.swift): 13 metodos faltantes (triangulate, boundingBox, volume, area, exportSTEP, etc.) — IMPLEMENTADOS *(done 2026-05-26)*
- BUG3 (SatinRenderer.swift): deltaTime use-before-definition — CORREGIDO *(done 2026-05-26)*
- BUG4 (ExportService.swift): MDLMesh(submesh:allocator:) invalido — CORREGIDO a vertex buffer API *(done 2026-05-26)*
- BUG5 (AnimationEngine.swift): simd_float4x4(rotation) missing — EXTENSION AGREGADA *(done 2026-05-26)*
- BUG6 (OCCTEngine.swift): measureBoundingBox duplicado — ELIMINADO *(done 2026-05-26)*
- BUG7 (Package.swift + project.yml): Satin 0.4.0→13.0.0 — CORREGIDO *(done 2026-05-26)*
- AppIcon + AccentColor assets creados en Resources/Assets.xcassets *(done 2026-05-26)*
- LaunchScreen reemplazado por UILaunchScreen (iOS 17+) *(done 2026-05-26)*
- Test target agregado a project.yml *(done 2026-05-26)*
- CI workflow: tests + archive + IPA export arreglados *(done 2026-05-26)*
- Operadores Shape - y & arreglados (usaban stubs, ahora usan CSGOperation.difference/intersection) *(done 2026-05-26)*
- Estructura unificada: Sources/ contiene 69+ archivos (Engines, CSG, CAD, Shaders, Services, Theme) *(done 2026-05-25)*
- Limpieza de 100+ archivos huérfanos *(done 2026-05-25)*
- .git anidado eliminado, repo unificado *(done 2026-05-25)*
- Satin dependency unified a Hi-Rez/Satin *(done 2026-05-25)*
