# Convenciones de código

- Arquitectura por "engines": cada capacidad = 1 archivo/clase engine en `Sources/Engines/` (p.ej. `SubdivisionEngine`, `VoxelRemeshEngine`); deformers de sculpt implementan protocolo `Deformer`.
- Vistas SwiftUI por modo en `Features/<X>Mode/`; view models en `Core/UI/`.
- Docs y comentarios del proyecto en español; identificadores en inglés.
- Cambios grandes: 1 módulo a la vez; al editar un símbolo, actualizar referencias (los view models de `Core/UI` y las vistas de `Features/` consumen los engines directamente).
- Undo/redo dual: brush-level en SculptEngine (50) + scene-level en CanvasViewModel (50) — no romper esa separación.
- Precaución histórica: sesiones previas dejaron APIs desalineadas entre engines y vistas (métodos renombrados sin actualizar llamadas). Antes de usar un método de un engine desde una vista, verificar con find_symbol que existe con esa firma.
