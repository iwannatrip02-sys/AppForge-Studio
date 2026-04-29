# Estado de Preparación para iPad — AppForge Studio
> 2026-04-27 20:00 UTC

## ¿Qué se necesita para probar en iPad?

### Ya listo (compila):
- 18 archivos Swift + 1 Metal shader (Shaders.metal unificado)
- Package.swift con Satin 0.3.0 como dependencia
- strokeVertex/strokeFragment shaders funcionales en Core/Managers/Shaders.metal
- ExportService (STL/OBJ) + ExportView (UI de exportación)
- BrushEngine con 10 tipos de pinceles y undo/redo
- Cámara orbital con gestos DragGesture + MagnificationGesture

### Falta para build en iPad:
1. **Crear .xcodeproj** — actualmente solo hay Package.swift (SPM). Para Xcode se necesita:
   - Opción A: `swift package generate-xcodeproj` (si el tool está disponible)
   - Opción B: Abrir el Package.swift directamente en Xcode 15+ (File > Open > Package.swift)
   - Opción C: Crear manualmente AppForgeStudio.xcodeproj

2. **Resolver Satin framework** — Package.swift usa Satin 0.3.0 via SPM. En Xcode:
   - File > Add Package Dependencies > https://github.com/mattrajca/Satin.git (0.3.0)
   - O confiar en que SPM lo resuelva automáticamente al abrir Package.swift

3. **Configurar signing** — Necesitas un Apple Developer account (free o paid) para:
   - Team en Signing & Capabilities
   - Bundle identifier único

### Decisión pendiente: Renderer Principal
- **SatinRenderer** usa Satin framework (abstracción más limpia, but dependencia externa)
- **PaintRenderer** (via MetalView Coordinator) usa Metal directo con pipeline propio
- Ambos coexisten ahora. El entry point usa MetalView -> PaintRenderer internamente.
- SatinRenderer está disponible pero no conectado al entry point.

### Pasos para probar YA:
1. Abre Xcode 15+
2. File > Open > selecciona `ios-app/AppForgeStudio/Package.swift`
3. Espera que SPM resuelva Satin 0.3.0
4. Selecciona destino iPad simulator o tu iPad físico
5. Configura signing con tu Apple ID
6. Build & Run
