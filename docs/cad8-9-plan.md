# CAD-8 y CAD-9 — Plan de Implementacion

## CAD-8: Constraint Visualization en Scene3D

**Estado actual:** Scene3D tiene constraintManager, vertexProvider, vertexUpdater pero no muestra constraints en 3D.

**Que falta:**
1. En CADModeView.swift: en el body, cuando selectedTab == .parametric, dibujar overlays de constraints sobre el modelo 3D
2. Las constraints deben dibujarse como: lineas de colores, iconos de perpendicular/tangente/horizontal, cotas de distancia/angulo
3. Usar vertexProvider/vertexUpdater de Scene3D para pasar datos de constraint al renderer
4. Conectar el .onChange de selectedTool para resaltar entidades constrainteadas

## CAD-9: Conectar Engines Avanzados a CADModeView

**Estado actual:**
- ChamferEngine.computeChamfer(edges:distance:mesh:segments:) existe
- FilletEngine.computeFillet(edges:radius:mesh:segments:) existe
- ShellEngine, LoftEngine, SweepEngine existen (sin leer firmas aun)
- CADTool enum tiene .fillet, .chamfer, .shell, .loft, .sweep
- CADModeView tiene cadTools toolbar con esos botones
- CADModeView tiene @State var filletRadius: Float = 0.05 y shellThickness: Float = 0.05

**Que falta:**
1. En CADModeView.swift: handlers para .fillet, .chamfer, .shell, .loft, .sweep que:
   a) Tomen la seleccion actual (edge/face del modelo)
   b) Instancien el engine correspondiente
   c) Ejecuten computeFillet/computeChamfer/etc con el mesh activo
   d) Actualicen la escena 3D con el resultado
2. UI: slider de radio/profundidad cuando se selecciona fillet/chamfer/shell
3. Integracion con Scene3D.models para pasar el mesh correcto

## Archivos a modificar
1. C:\Users\USUARIO\Projects\appforge-studio\ios-app\AppForgeStudio\Features\CADMode\CADModeView.swift (handler de tools + constraint overlay)
2. C:\Users\USUARIO\Projects\appforge-studio\ios-app\AppForgeStudio\Core\Engines\Scene3D.swift (metodo drawConstraints si aplica)

## Archivos a leer (referencia)
- Core/Engines/ShellEngine.swift
- Core/Engines/LoftEngine.swift
- Core/Engines/SweepEngine.swift
- Features/CADMode/CADSketchEngine.swift (para entender flujo sketch→extrude→engine)
