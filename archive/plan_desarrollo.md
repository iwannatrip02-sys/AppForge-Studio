# Plan de Desarrollo — AppForge Studio

## Estado Actual del Código (26 archivos explorados)

### App Principal (funcional)
- `ios-app/Sources/AppForgeStudioApp.swift` — Entry point Metal+Satin, renderiza cubo con cámara orbital
- `ios-app/Sources/ContentView.swift` — Gestos de drag/orbit y pinch/zoom
- `ios-app/Sources/Shaders.metal` — Shaders básicos strokeVertex/strokeFragment
- Dependencia: Satin 0.3.0, iOS 17+

### Sistema de Pinceles (parcial)
- `ios-app/Sources/Renderer/Pincel.swift` — StrokePoint, Stroke, BrushManager (gestión de trazos activos)
- `ios-app/Sources/Renderer/PincelRenderer.swift` — StrokeRenderer GPU-based con pipeline Metal (blending alpha)
- `ios-app/AppForgeStudio/Models/BrushStroke.swift` — BrushStroke con 5 tipos: round, flat, textured, airbrush, clay + StrokeSegment con interpolación

### Modelos 3D (estructura)
- `ios-app/AppForgeStudio/Models/Mesh.swift` — Vertex, Mesh con uploadToGPU, Model con transform
- `ios-app/AppForgeStudio/Models/Scene3D.swift` — Scene3D con Camera, Lighting, models + strokes
- `ios-app/AppForgeStudio/Core/Managers/PaintRenderer.swift` — Renderizador de pintura
- `ios-app/AppForgeStudio/Core/Managers/Shaders.metal` — Shaders del core

### Modos de Edición (esqueletos)
- `ios-app/AppForgeStudio/Features/CADMode/CADModeView.swift` + `Tools/`
- `ios-app/AppForgeStudio/Features/SculptMode/SculptModeView.swift` + `Brushes/`
- `ios-app/AppForgeStudio/Features/HybridMode/HybridModeView.swift`

### UI
- `ios-app/AppForgeStudio/UI/Components/MetalView.swift` — Vista Metal personalizada
- `ios-app/AppForgeStudio/UI/Components/Navigation/` — Navegación
- `ios-app/AppForgeStudio/UI/Preview/` — Previews
- `ios-app/AppForgeStudio/Resources/` — Recursos

### Carpetas vacías (por implementar)
- `AppForgeStudio/MetalEngine/` — Vacío
- `AppForgeStudio/Services/` — Vacío
- `AppForgeStudio/Views/` — Vacío

## Fase 1 — Consolidación del Motor de Render (SEMANA 1)

### 1.1 Unificar sistema de pinceles
Hay DUPLICACIÓN: `Pincel.swift` (Sources/Renderer) y `BrushStroke.swift` (AppForgeStudio/Models) definen estructuras similares pero incompatibles.

**Acción:** Refactorizar para usar `BrushStroke.swift` como modelo único y `PincelRenderer.swift` como renderer.

### 1.2 Implementar render de trazos completo
- PincelRenderer.render() tiene TODO — implementar encoding geometry (billboard quads por punto)
- Crear vertex buffer con quads orientados a cámara por cada StrokePoint
- Soportar hardness (degradado alpha en fragment shader)
- Soportar presión variable a lo largo del trazo

### 1.3 Shaders avanzados
- Shader de stroke con falloff por hardness
- Shader de vista previa de pincel (cursor 3D)
- Sombreado básico en strokes (normal-based shading)

## Fase 2 — Modo Sculpt (SEMANA 2)

### 2.1 Escultura básica
- Implementar deformación de malla basada en BrushStroke
- Brush types: clay (push/pull), smooth, inflate, pinch, flatten
- Algoritmo de impacto: raycast desde cámara → punto en mesh → afectar vértices en radio
- Interpolación entre puntos para trazos suaves (StrokeSegment ya existe)

### 2.2 Pintura de vértices
- Vertex color blending en la malla basado en BrushStroke
- Brush types: round con hardness variable, airbrush con opacidad acumulativa, textured con imagen
- Preview en tiempo real del color antes de aplicar
- Deshacer/rehacer básico

### 2.3 Escultura con simetría
- Eje X por defecto
- Espejar strokes en el eje seleccionado

## Fase 3 — Modo CAD (SEMANA 3)

### 3.1 Primitivas paramétricas
- Box, Sphere, Cylinder, Torus con controles de resolución
- Previsualización antes de confirmar
- Transformaciones: mover, rotar, escalar con handles 3D

### 3.2 Boolean operations
- Unión, intersección, diferencia
- Usar CSG (Constructive Solid Geometry) o lib externa

### 3.3 Herramientas de precisión
- Snapping a grid, vértices, aristas
- Medición de distancias
- Alineación de objetos

## Fase 4 — Exportación STL/OBJ (SEMANA 4)

### 4.1 Exportación STL
- Triangulación de mallas existentes
- Exportar escena completa o selección
- STL binario y ASCII
- Compartir sheet nativo de iOS

### 4.2 Exportación OBJ
- Con normales, UVs, materiales
- Multi-objeto

### 4.3 Carga de modelos
- Importar STL/OBJ desde archivos
- Drag & drop desde Files app
- Optimización de mallas (vertex deduplication, quad→tri)

## Fase 5 — Modo Híbrido y UI (SEMANA 5)

### 5.1 Modo Híbrido funcional
- Combinar herramientas CAD y Sculpt en una misma sesión
- Capas: CAD objects vs sculpted mesh
- Convertir CAD mesh a sculpt mesh y viceversa

### 5.2 UI polishing
- Toolbar contextual (cambia según modo activo)
- Paneles de propiedades (brush size, hardness, color picker)
- Menú de modos con transición suave
- Dark mode nativo

### 5.3 Performance
- LOD (Level of Detail) para mallas grandes
- Render por tiles para strokes densos
- Pooling de buffers Metal

## Fase 6 — Calidad y Release (SEMANA 6)

### 6.1 Testing
- Unit tests para modelos (BrushStroke, Mesh, Scene3D)
- UI tests para gestos y modos
- Performance testing con mallas de 100K+ vértices

### 6.2 App Store prep
- App icon, screenshots, descripción
- Privacy policy (sin recolección de datos)
- TestFlight beta

### 6.3 Documentación
- README con instrucciones de build
- Guía de uso para usuarios
- API docs para contribuidores

## Siguientes archivos a leer para implementar
- `CADModeView.swift` — Para entender estructura de CAD tools
- `SculptModeView.swift` + `Brushes/` — Para entender esqueleto de sculpt
- `PaintRenderer.swift` — Para ver render pipeline actual
- `MetalView.swift` — Para entender integración Metal-SwiftUI
- `HybridModeView.swift` — Para planificar integración de modos
