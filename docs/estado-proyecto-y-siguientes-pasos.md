# AppForge Studio — Estado Actual y Siguiente Fase
> Generado: 2026-04-29 | Post-auditoria de código real

## Estado Actual (verificado contra 49 archivos .swift)

### Implementado ✅
- **4 modos de app:** CAD, Sculpt, Hybrid, Render via Picker
- **Modelos 3D:** Scene3D, Camera, Lighting, Model (struct), Model3D (class con Metal buffers), Mesh, Vertex, BrushStroke
- **BrushEngine:** 10 tipos de pincel, stroke modes, simetría, falloff GPU
- **Shaders Metal:** vertex_main, fragment_main, strokeVertex, strokeFragment en Shaders.metal
- **Undo/Redo:** BrushEngine (50 stacks stroke-level) + CanvasViewModel (50 stacks scene-level)
- **Renderers:** SatinRenderer, PaintRenderer (pipeline Metal 2048x2048), PincelRenderer (billboard quads)
- **Touch + Raycast:** MetalView con ray-triangle intersection, deformación en tiempo real
- **Exportación OBJ/STL:** ExportService via ModelIO, ExportView con progreso y alertas async
- **CAD Tools (5/5):** BevelEngine, BooleanEngine, ExtrusionEngine, LoopCutEngine, MeasureEngine
- **SculptEngine + 8 Deformers:** Crease, Flatten, Grab, Inflate, Move, Pinch, Smooth, Twist
- **Animación:** AnimationEngine con keyframes, clips, easing (6 tipos) — AISLADO, sin integrar
- **Subdivisión:** SubdivisionEngine con Catmull-Clark — AISLADO, sin conectar a UI

### Problemas Identificados 🟡

#### 1. Duplicación Model (struct) vs Model3D (class)
- **Model.swift** — struct plano con `meshes: [Mesh]` y transform, sin Metal
- **Model3D.swift** — class con MTLBuffer, vertexCount, color, cadHistoryID
- **Impacto:** ExportView recibe `let model: Model` (el struct), pero los renderers trabajan con Model3D (la class). Conversión manual necesaria cada vez.
- **Recomendación:** Unificar como `class Model3D` y eliminar `Model` struct, o crear un protocolo `ModelRepresentable`

#### 2. ExportView viola MVVM
- ExportView recibe `let model: Model` en lugar de obtener el modelo activo desde `ExportViewModel`
- **Impacto:** Si el usuario cambia de modelo en la escena, ExportView no se actualiza
- **Recomendación:** ExportViewModel debe exponer `@Published var selectedModel: Model3D` y ExportView leerlo de ahí

#### 3. AnimationEngine sin integración en AppState
- AnimationEngine existe como clase @MainActor con keyframes y clips completos
- Pero NO está declarado como `@Published var` en AppState
- Tampoco hay UI de animación (linea de tiempo, play/pause)
- **Recomendación:** Agregar `@Published var animationEngine = AnimationEngine()` en AppState

#### 4. ExportViewModel y ToolViewModel no están en AppState
- ARCHITECTURE.md dice que están en AppState, pero el código real de AppState.swift solo tiene canvasVM y satinRenderer
- **Recomendación:** Agregar `@Published var exportVM = ExportViewModel()` y `@Published var toolVM = ToolViewModel()`

## Siguiente Fase: Fase 4 — Animación + Subdivisión + Unificación

### Objetivo
Completar la Fase 4 del roadmap e integrar los módulos aislados en la app funcional.

### Tareas (ordenadas)

#### Paso 1: Integrar AnimationEngine en AppState
- Agregar `@Published var animationEngine = AnimationEngine()` en AppState.swift
- Crear `AnimationView.swift` con timeline, play/pause, selector de clip
- Conectar con la escena 3D para animar transforms de modelos

#### Paso 2: Integrar SubdivisionEngine
- Agregar botón "Subdividir" en SculptModeView
- SubdivisionEngine debe recibir el Model3D activo y devolver malla subdividida
- Implementar UI de slider para nivel de subdivisión (1-4)

#### Paso 3: Unificar Model/Model3D
- Convertir `Model` struct en typealias o extensión de `Model3D`
- Actualizar ExportService para trabajar con Model3D directamente
- Eliminar `let model: Model` de ExportView y usar `exportVM.selectedModel`

#### Paso 4: Integrar ViewModels faltantes
- Agregar exportVM y toolVM a AppState
- Conectar ToolViewModel con los pinceles y herramientas reales en SculptModeView/CADModeView

### Priorización
1. **Crítica:** Integrar ViewModels en AppState (paso 4 + paso 1) — sin esto la app no usa los módulos
2. **Alta:** Unificar Model/Model3D (paso 3) — elimina bugs silenciosos de conversión
3. **Media:** UI de animación (paso 1b) + subdivisión (paso 2) — features visibles para el usuario

### Tiempo estimado
- Integración básica: 2-3 horas
- UI funcional completa: 4-6 horas
