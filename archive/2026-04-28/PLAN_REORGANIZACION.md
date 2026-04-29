# Plan de Reorganizacion - AppForge Studio
> 2026-04-28 00:06 UTC

## FASE 1: Migrar codigo unico de Sources/ a AppForgeStudio/

### Archivos UNICOS en Sources/ a migrar:
1. Sources/Core/AppState.swift -> AppForgeStudio/Core/AppState.swift
2. Sources/Models/Model3D.swift -> AppForgeStudio/Models/Model3D.swift
3. Sources/Renderer/SceneRenderer.swift -> AppForgeStudio/Core/Managers/SceneRenderer.swift
4. Sources/UI/ColorPickerView.swift -> AppForgeStudio/UI/Components/ColorPickerView.swift
5. Sources/UI/ToolbarView.swift -> AppForgeStudio/UI/Components/ToolbarView.swift

### Duplicados con contenido diferente (fusionar):
- ExportService.swift: Sources (2917b) tiene meshToMDL completo. AppForge (1993b) version reducida
- Scene3D.swift: Sources (1141b) usa Model3D. AppForge (1701b) usa Model de Satin. CORRECTA: AppForge

## FASE 2: Eliminar Sources/ (codigo legacy)
## FASE 3: Eliminar basura (24 .md, clones blender, txt sueltos)
## FASE 4: Inicializar git

## ARBOL FINAL:
appforge-studio/
  ios-app/AppForgeStudio/  (codigo activo, 66+5 archivos)
  docs/                     (plan, roadmap, sesiones archivadas)
  GOTCHI.md
  ROADMAP.md
  CHANGELOG.md
  workspace/
