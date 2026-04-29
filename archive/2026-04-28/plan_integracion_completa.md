# Plan de Integración Completa — AppForge Studio

## Arquitectura Actual (basada en 22+ archivos verificados)

### Entry Point
- `AppForgeStudio/AppForgeStudioApp.swift` — @main, maneja scene/strokes/showExport como @State, 4 modos

### ViewModels (DUPLICADOS)
- **Core/ViewModels/CanvasViewModel.swift** — camera controls (orbit, zoom, pan, reset), sin undo/redo
- **ViewModels/CanvasViewModel.swift** — undo/redo, esfera por defecto, generateSphereVertices()
- **Core/ViewModels/ToolViewModel.swift** — (no existe, el unico es ViewModels/ToolViewModel.swift)
- **Core/ViewModels/ExportViewModel.swift** — validacion, beginExport con progreso

### Vistas (UI)
- `UI/Components/MetalView.swift` — UIViewRepresentable, Coordinator con renderizado Metal directo
- `UI/Components/ContentView.swift` — maneja gestos (drag, magnification), camara, strokes, paint
- `Features/CADMode/CADModeView.swift` — toolbar CAD + ContentView
- `Features/SculptMode/SculptModeView.swift` — brush selector + ContentView + BrushEngine local
- `Features/HybridMode/HybridModeView.swift` — 3 submodos (CAD/sculpt/paint)
- `Features/ExportMode/ExportView.swift` — UI export con formatos STL/OBJ

### Modelos
- `Models/Mesh.swift` — Vertex, Mesh, Model
- `Models/Scene3D.swift` — Scene3D, Camera, Lighting
- `Models/BrushStroke.swift` — BrushPoint, BrushType, BrushStroke, StrokeSegment

### Render
- `Core/Managers/Shaders.metal` — vertex_main, fragment_main, strokeVertex, strokeFragment
- `Core/Managers/PaintRenderer.swift` — pipeline Metal propio, paint texture 2048x2048
- `Core/Managers/PincelRenderer.swift` (StrokeRenderer) — stroke rendering con blending
- `AppForgeStudio/SatinRenderer.swift` — wrapper de Satin (NO USADO)

### Servicios
- `Core/Services/ExportService.swift` — exportToOBJ/STL via ModelIO

### Features
- `Features/SculptMode/Brushes/BrushEngine.swift` — paint/sculpt strokes, undo/redo de vertices
- `Sculpting/SculptEngine.swift` — deformers (inflate, pinch, smooth, etc.)

## Problemas Detectados

1. **ViewModels duplicados** — CanvasViewModel existe en 2 lugares con funcionalidad complementaria pero no unificada
2. **SatinRenderer sin usar** — Dependencia Satin en Package.swift pero no se usa en ninguna vista
3. **Estado centralizado en App** — scene/strokes como @State, deberian ser @StateObject via ViewModel
4. **ContentView duplica logica de camara** — MetalView.orbitCamera() existe tambien en CanvasViewModel
5. **ExportView no conectado** — Usa @State local en vez de ExportViewModel
6. **SculptModeView con BrushEngine local** — Deberia usar ToolViewModel compartido
7. **Package.swift configurado para Satin** — Dependencia innecesaria, ralentiza build

## Plan de Integración (7 Pasos)

### Paso 1: Unificar CanvasViewModel
Combinar Core/ViewModels/CanvasViewModel.swift (camara) + ViewModels/CanvasViewModel.swift (undo/redo) en un solo archivo.

### Paso 2: Crear AppState central
@StateObject con canvasVM, toolVM, exportVM, selectedMode, showExport.

### Paso 3: Refactor AppForgeStudioApp.swift
Usar AppState en vez de @State dispersos.

### Paso 4: Conectar vistas con ViewModels
Pasar canvasVM, toolVM, exportVM a cada vista hija.

### Paso 5: Refactor ContentView
Eliminar logica de camara duplicada, delegar a canvasVM.

### Paso 6: Conectar ExportView con ExportViewModel
Usar @ObservedObject var exportVM.

### Paso 7: Limpiar Package.swift
Eliminar dependencia Satin si no se usa.

## Archivos a Modificar

1. MODIFICAR: ViewModels/CanvasViewModel.swift (unificado)
2. CREAR: ViewModels/AppState.swift
3. MODIFICAR: AppForgeStudio/AppForgeStudioApp.swift
4. MODIFICAR: Features/CADMode/CADModeView.swift
5. MODIFICAR: Features/SculptMode/SculptModeView.swift
6. MODIFICAR: Features/HybridMode/HybridModeView.swift
7. MODIFICAR: Features/ExportMode/ExportView.swift
8. MODIFICAR: UI/Components/ContentView.swift
9. MODIFICAR: Package.swift (si aplica)

## Tiempo Estimado por code_agent
- Lectura de archivos: ~30s
- Analisis y escritura: ~120s
- Total: ~3-4 minutos con DeepSeek V4 Pro
