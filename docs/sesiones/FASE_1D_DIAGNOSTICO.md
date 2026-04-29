# Fase 1D — Diagnostico Completo

## Archivos del proyecto (workspace: ios-app/):

### Sources/AppForgeStudioApp.swift (2659 chars)
- @main app con scene 3D, estado strokes, 3 modos (sculpt/cad/hybrid)
- Init: genera esfera con generateSphereVertices(radius:0.8, segments:32), crea Mesh, sube a GPU, crea modelo y scene
- Body: Picker de modos, navega a SculptModeView/CADModeView/HybridModeView

### Sources/ContentView.swift (3000+ chars)
- Binding scene, strokes, brushEngine? optional, isPaintMode
- DragGesture con minimumDistance 20 (camara) o 2 (pintura)
- onTouch3D callback definido pero SIN conectar a brushEngine
- handleTouch vacio: solo registra currentStroke cuando isPaintMode

### Sources/Shaders.metal (completo)
- strokeVertex: transforma VertexIn con MVP, pasa color y hardness
- strokeFragment: calcula falloff circular basado en hardness, alpha blending
- FALTA: vertex_main y fragment_main para renderizar malla con iluminacion

### Sources/Renderer/PincelRenderer.swift (StrokeRenderer, 3000+ chars)
- class StrokeRenderer con pipeline state para strokeVertex/strokeFragment
- init: carga library, crea pipeline con blending, maxQuads: 65536
- render: encoder, setVertexBytes con MVP, renderiza strokes como quads billboard

### UI/Components/MetalView.swift (3000+ chars)
- UIViewRepresentable wrapping MTKView
- Coordinator con: scene, strokes, onTouch3D, device, commandQueue, pipelineState, depthState, strokeRenderer
- setup: crea pipeline state para mesh (vertex_main/fragment_main) y depth state
- draw: renderiza modelos con pipeline state de malla
- FALTA: gestos tactiles, raycast hitTest

### Features/SculptMode/SculptModeView.swift (3000+ chars)
- UI completa: Picker Esculpir/Pintar, 9 brush options, sliders radio/dureza/opacidad, color picker, toggle simetria
- brushEngine = BrushEngine()
- updateBrush() conecta brush a engine

### Features/SculptMode/Brushes/BrushEngine.swift (3000+ chars)
- currentBrush, radius, hardness, opacity, color, pressure, symmetry
- undoStack/redoStack con max 50 estados
- sculptStroke(at:on:): guarda original, llama applyDeformation, aplica simetria si activa
- applyDeformation: iteracion sobre vertices, calcula falloff gaussiano
- FALTA: implementacion completa para round/flat/inflate/pinch/smooth/crease/grab/clay/airbrush

### Models/BrushStroke.swift (1591 chars)
- BrushPoint: position, normal, pressure, tilt
- BrushType: 10 tipos (round, flat, textured, airbrush, clay, inflate, pinch, smooth, crease, grab)
- StrokeMode: paint, sculpt, hybrid
- BrushStroke: points array, brushType, color, radius, hardness, opacity, mode
- StrokeSegment: interpolacion con simd_mix

### Models/Mesh.swift (completo)
- Vertex: position, normal, uv, color
- Mesh: vertices, indices, vertexBuffer, indexBuffer
- uploadToGPU: makeBuffer con .storageModeShared
- Model: meshes array, transform (identity), name

### Models/Scene3D.swift (1641 chars)
- Scene3D: models, strokes, camera, lighting
- Camera: position(0,0,3), target(0,0,0), up(0,1,0), fov=45, near=0.1, far=100
- Lighting: ambient(0.2), directional(-1,-1), intensity=0.8
- addModel, addStroke
- FALTA: getFirstMesh() helper

## Gaps identificados:
1. MetalView: SIN gestos tactiles ni raycast 3D
2. ContentView: onTouch3D callback no conectado a brushEngine
3. Shaders: FALTA vertex_main/fragment_main para malla con luz
4. BrushEngine: applyDeformation incompleto
5. Scene3D: FALTA getFirstMesh()
