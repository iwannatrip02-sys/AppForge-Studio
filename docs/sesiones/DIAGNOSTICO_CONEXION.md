# Diagnostico de Conexion — SatinRenderer + UI
> 2026-04-27

## Estado actual
- **SatinRenderer.swift**: Clase minima con init(setup/draw/addMesh). NO conectado a UI ni MetalView.
- **MetalView.swift**: UIViewRepresentable con pipeline Metal propio (perspective_fov, lookAt, raycast). Renderiza Scene3D directamente.
- **CanvasViewModel.swift**: ObservableObject con Scene3D, undo/redo a nivel escena, orbitCamera.
- **AppForgeStudioApp.swift**: @main con 4 modos (CAD/Esculpir/Hybrid/Render). Boton Exportar.
- **ExportService.swift**: Exportacion STL/OBJ funcional con ModelIO.
- **ExportView.swift**: UI con selector de formato + file picker.
- **BrushEngine.swift**: Paint + sculpt con deformacion y undo/redo por vertices.
- **Scene3D.swift**: Struct con models, strokes, camera, lighting.

## Lo que falta conectar
1. SatinRenderer -> CanvasViewModel: Que el renderer use la escena del VM y se refresque con @Published.
2. Modo Render en AppForgeStudioApp: Actualmente solo muestra un Text("Render View"). Debe instanciar SatinRenderer y mostrar su output.
3. ExportView -> CanvasViewModel: Pasar el modelo seleccionado al ExportService.
4. Subdivision: No existe. Pendiente para fase 4.
5. Animacion basica: No existe. Pendiente para fase 4.

## Plan de accion
1. Refactor SatinRenderer para aceptar Scene3D como Binding.
2. Crear SatinRendererView (UIViewRepresentable) que envuelva SatinRenderer.
3. Actualizar AppForgeStudioApp modo .render para usar SatinRendererView.
4. Conectar ExportView con CanvasViewModel.scene.models.
