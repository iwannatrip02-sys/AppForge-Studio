# Analisis de Usabilidad y Bugs — 30 Abril 2026

## Estado Actual de Conexiones Clave

### AnimationEngine ↔ SatinRenderer ✅ FUNCIONAL
- SatinRenderer tiene `updateAnimation()` con deltaTime real usando CACurrentMediaTime()
- Descompone matriz 4x4 en translation + quaternion rotation correctamente
- AppState.setRenderer() conecta onTransformsApplied y animationVM.onFrame
- **Bug resuelto (t18):** SatinRendererView ahora acepta externalRenderer opcional y llama `updateAnimation()` en cada frame

### Conexiones rotas que impiden playback real

1. **Ninguna ModeView pasa externalRenderer** — todas las views (CADModeView, SculptModeView, HybridModeView, AnimationModeView) crean su propio SatinRendererView sin pasar `appState.satinRenderer`. El setRenderer() de AppState nunca se usa realmente.
   - Archivos afectados: Features/AnimationMode/AnimationModeView.swift, Features/CADMode/CADModeView.swift, Features/SculptMode/SculptModeView.swift, Features/HybridMode/HybridModeView.swift

2. **AppForgeStudioApp.swift recrea views en cada cambio de modo** — usa `switch appState.selectedMode` con `.equatable()` y `.matchedGeometryEffect()`. Esto destruye el MTKView y SatinRenderer asociado cada vez que el usuario cambia de modo (1-2s pantalla negra).

## Bugs P1 Identificados

| # | Bug | Archivo | Severidad |
|---|-----|---------|-----------|
| 1 | MTKView recreado en cambio de modo | AppForgeStudioApp.swift | P1 |
| 2 | BrushEngine solo 2D (CGPoint, sin proyeccion a malla 3D) | Core/Engines/BrushEngine.swift | P1 |
| 3 | ModeViews no reciben externalRenderer de AppState | Features/*/AnimationModeView.swift y otros | P1 |
| 4 | Scene3D no conforma Codable — sin state restoration | Models/Scene3D.swift | P2 |
| 5 | StrokeRenderer usa shaders que no existen (strokeVertex/strokeFragment) | UI/Components/StrokeRenderer.swift | P1 |
| 6 | PaintRenderer y BrushEngine no estan conectados — brush 2D nunca colorea textura 3D | Core/Managers/PaintRenderer.swift + Engines/BrushEngine.swift | P1 |

## Puntaje de Usabilidad Real: 2/10

### Lo que funciona (2 puntos):
- Pipeline Metal renderiza mallas con iluminacion difusa (Shaders.metal vertex_main/fragment_main completos)
- ExportService exporta OBJ/STL/USDZ con try/catch (bugs P0 corregidos)
- AnimationEngine evalua keyframes con easing interpolado correctamente
- AppState tiene arquitectura MVVM con setRenderer() para conectar componentes

### Lo que NO funciona (8 puntos perdidos):
- **No hay playback real de animacion** — AnimationModeView no recibe renderer conectado
- **Brush 2D no pinta en 3D** — BrushEngine usa CGPoint, nunca llama a PaintRenderer
- **Interfaz se reinicia en cada modo** — recreacion de MTKView causa pantalla negra 1-2s
- **Sin state restoration** — al cerrar app se pierde escena (Scene3D no es Codable)
- **Shaders de stroke no existen** — StrokeRenderer crashearia al intentar dibujar
- **Sin gestos 3D** — no hay camara orbital, zoom, ni interaccion con el modelo
- **Sin carga de modelos real** — ModelLoadService no verificado, probablemente incompleto

## Proximas Correcciones Prioritarias

1. Pasar `externalRenderer: appState.satinRenderer` a todas las SatinRendererView en las ModeViews
2. Migrar el MTKView a un ZStack compartido fuera del switch de modos
3. Conectar BrushEngine con PaintRenderer mediante proyeccion de rayos 3D
4. Agregar Codable a Scene3D y Camera y Lighting
