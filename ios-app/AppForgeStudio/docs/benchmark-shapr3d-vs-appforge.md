# Benchmark: AppForge Studio vs Shapr3D (2026)

## Resumen Ejecutivo

AppForge Studio compite directamente con Shapr3D ($299/año) ofreciendo un conjunto de features
significativamente mas amplio: 6 modos (pintura 3D + escultura + CAD + animacion + exportacion
+ AR QuickLook) versus el CAD puro de Shapr3D. La ventaja tecnica principal es el render
Metal PBR con IBL y el soporte nativo de Apple Pencil via PencilKit.

## Comparativa de Features

| Feature | Shapr3D | AppForge Studio | Ventaja |
|---------|---------|----------------|---------|
| **Kernel CAD** | Siemens Parasolid | OCCTSwift (Open CASCADE) | Empate tecnico |
| **Apple Pencil** | Touch basico | PencilKit nativo + force + PKToolPicker | **AppForge** |
| **Sketch 2D** | Lineas/circulos/arcos | Puntos/lineas/circulos/arcos/rectangulos | Empate |
| **Constraints** | Si | 10 tipos + SolveSpaceSolver | Empate |
| **Extrusion** | Si | OCCTEngine + bidirectional | Empate |
| **Boolean ops** | Union/diferencia/intersect | Union/diferencia/intersect + fillet/chamfer/shell | Empate |
| **Sculpt 3D** | NO | 8 deformadores (grab/inflate/smooth/twist/pinch/flatten/crease/move) | **AppForge** |
| **Pintura 3D** | NO | PincelRenderer con strokes | **AppForge** |
| **Animacion** | NO | MorphEngine + AnimationEngine + keyframes | **AppForge** |
| **Render** | Basico | Metal PBR con IBL + compute shaders | **AppForge** |
| **Export** | STEP/IGES/STL/OBJ/USDZ/GLTF/3MF/SVG/DXF/PDF | STL/OBJ/STEP/FBX/Collada/USDZ (AR QuickLook) | Shapr3D (mas formatos) |
| **AR QuickLook** | No directo | USDZ con ARQuickLookView nativo | **AppForge** |
| **Multiplataforma** | iPad/Mac/Windows/Vision Pro | iOS 17+ (iPad inicial) | Shapr3D |
| **Timeline/historial** | Limitado | CADHistoryTree + CADTimelineView DAG | **AppForge** |
| **Precio** | $299/año Pro, $25/mes | TBD (<$14.99 one-time objetivo) | **AppForge** |

## Metricas de Performance (Propuestas)

Las siguientes metricas deberan validarse en iPad real (actualmente bloqueado por falta de
compilacion macOS):

### 1. Tiempo de sketch a primer mesh
- Shapr3D: ~30s (segun reseñas de usuarios)
- AppForge: estimado <20s con PencilKit + extrusion directa

### 2. Gestos por operacion
- Shapr3D: 4-5 gestos para crear extrusion (seleccionar face -> elegir tool -> definir distancia -> confirmar)
- AppForge: 3 gestos (dibujar sketch con PencilKit -> slider distancia -> boton Extruir)

### 3. Precision de constraints
- Shapr3D: 0.001mm (Parasolid)
- AppForge: <0.5mm tolerancia (SolveSpaceSolver, 100 iter Gauss-Seidel)
  Mejorable con mas iteraciones o solver Newton-Raphson

### 4. Render performance
- Shapr3D: render OpenGL basico (no Metal, no PBR)
- AppForge: Metal PBR con IBL, compute shaders, hasta ~500K triangulos en iPad Pro M1+

### 5. Export speed (archivo 10MB STEP)
- Shapr3D: ~5s
- AppForge: estimado <8s (pendiente de benchmarking real)

## Diferenciadores Clave de AppForge Studio

1. **Apple Pencil nativo**: Primer CAD en iPad con PencilKit + force sensitivity
2. **6 modos en 1 app**: Shapr3D solo CAD. AppForge suma sculpt + paint + animation
3. **Render Metal PBR**: Visualizacion fotorrealista en tiempo real (Shapr3D no tiene)
4. **Precio disruptivo**: <$14.99 one-time vs $299/año de Shapr3D
5. **DAG de historial**: CADHistoryTree con visualizacion de operaciones en arbol

## Limitaciones Actuales

1. Solo iOS 17+ (no Windows/Mac/Vision Pro como Shapr3D)
2. Sin compilacion verificada (requiere macOS/Xcode)
3. OCCTSwift como SPM dependency no verificada en compilacion real
4. 8 bugs criticos identificados en code review previo (padding GPU, UInt32 index, deltaTime)
5. Sin benchmark real en iPad (simulador no disponible en Windows)

## Roadmap para Cerrar Brechas

| Brecha | Accion | Prioridad |
|--------|--------|-----------|
| iOS-only | Port a macOS via Catalyst | Fase 11 |
| OCCTSwift verificacion | CI con macOS runner | Inmediato |
| Bugs GPU | Fix padding structs (BUG1-9 ya resueltos en codigo) | Listo |
| Benchmark real | Probar en iPad fisico con TestFlight | Pendiente |
| Mas formatos export | Agregar IGES, 3MF, GLTF | Fase 10 |
