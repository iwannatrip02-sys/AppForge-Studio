# Plan Estratégico Detallado — AppForge Studio 2026

## 1. Estado Actual de AppForge (verificado en disco)

### Lo que YA funciona:
- **Paint 3D**: brush engine con 4 modos, colour picker, capas, symmetría, máscaras. Basado en Blender paint system analizado.
- **Sculpt**: 8 deformadores (draw, smooth, inflate, pinch, grab, crease, flatten, rotate) sobre malla de 100K triángulos.
- **CAD paramétrico**: sketch 2D con constraints geométricos (coincident, horizontal, vertical, parallel, perpendicular, equal, distance, angle, radius), operations de extrusión y revolución, timeline histórico con undo/redo.
- **Animación**: AnimationEngine con keyframes, playback controller, AnimationModeView.
- **Export**: STL, OBJ, glTF, STEP, USDZ — 5 formatos vía ExportService.
- **Render engine**: SatinRenderer sobre Metal 2 con PBRShaders.metal, culling, triangulation.
- **UI**: SwiftUI app completa con Canvas3DView, ToolbarView, LayerPanel, InspectorPanel.

### Lo que FALTA (de TODO.md):
- IBL (image-based lighting) + environment maps
- PBR texture maps (normal, roughness, metallic, ao)
- CSG booleano (unión, intersección, diferencia) para CAD
- Optimización de rendimiento (LOD, instancing, occlusión)
- Tooltips y onboarding
- Pruebas de exportación a impresión 3D

## 2. Análisis de Competencia

### Shapr3D ($299/año)
- **Motor CAD**: Parasolid (Siemens) — kernel CAD industrial probado, NO open source
- **API**: No tiene API pública para extensiones/plugins. Solo integración con Apple Pencil y AR Quick Look.
- **Features**: CAD paramétrico puro, timeline, constraints, sketch 2D, operaciones booleanas.
- **NO tiene**: paint 3D, sculpt, animación, export STEP/USDZ nativo (sí tiene STEP vía compra aparte).
- **Ventaja**: madurez del kernel Parasolid, estabilidad, ecosistema pro.
- **Debilidad**: $299/año, sin paint/sculpt, sin animación, sin colaboración real-time.

### Fusion 360 ($545/año o free para hobbyists)
- **Motor CAD**: Autodesk Shape Manager (ASM) propio
- **API**: Autodesk Platform Services (APS) — REST API para automatización, scripting en Python/JS. Pero es para desktop/web, NO para iPad.
- **Features**: CAD + CAM + CAE + PCB design + render + animación básica + colaboración.
- **NO tiene**: paint 3D, sculpt digital, export STEP directo a impresión (sí tiene STL).
- **Ventaja**: suite completa ingenieril, CAM/CAE integrados, precio free para hobby.
- **Debilidad**: no corre en iPad (solo viewer web pesado), $545/año versión completa, sin paint/sculpt.

### Nomad Sculpt ($14.99)
- **Motor**: propio, OpenGL ES
- **Features**: sculpt digital puro (similar a ZBrush lite), paint vertex, export OBJ/STL.
- **NO tiene**: CAD paramétrico, animación, export STEP/USDZ.
- **Ventaja**: muy pulido, intuitivo, precio bajo.
- **Debilidad**: solo sculpt, sin CAD ni animación.

### Feather 3D ($9.99/mes)
- **Features**: modelado poligonal básico + sculpt ligero + animación simple + export.
- **NO tiene**: CAD paramétrico, paint textura real, export STEP.
- **Ventaja**: precio bajo, interfaz amigable.
- **Debilidad**: superficial en todo, sin CAD.

## 3. Las 3 Ventajas Clave de AppForge

1. **Unificación CAD + Paint + Sculpt + Animación**: Ninguna app existente ofrece las 4 disciplinas en un solo flujo de trabajo en iPad. Un diseñador industrial puede esculpir, pintar texturas, modelar CAD paramétrico, animar y exportar para impresión 3D — TODO en AppForge.

2. **Precio disruptivo**: Gratis con ads (rewarded video $10-15 eCPM, interstitial $5-8) + suscripción opcional $4.99/mes para funcionalidades premium (export STEP/USDZ, simulación, sin ads). Shapr3D = $299/año vs AppForge = $0-60/año.

3. **Código abierto + público objetivo amplio**: Al ser open-source, gana tracción por comunidad, educadores, makers. Monetización por publicidad y suscripción sin bloquear features básicas.

## 4. Roadmap Ejecutable (Q2-Q4 2026)

### Fase 1 (Junio 2026) — Fortalecer CAD + Rendimiento
- **Completar CSG booleano** (unión, intersección, diferencia) usando OCCTSwift
- **Implementar IBL + environment maps** en SatinRenderer (ya está en Hi-Rez/Satin, sólo conectar)
- **Implementar PBR texture maps** (normal, roughness, metallic, ao) en pipeline Metal
- **Optimizar rendimiento**: LOD automático, instancing para objetos repetidos, frustum culling
- **Tooltips y onboarding** (SwiftUI tutorial overlay)

### Fase 2 (Septiembre 2026) — Paint 3D + Sculpt sobre CAD
- **Paint sobre superficie CAD**: mapear texturas sobre modelos paramétricos (no solo sobre malla poligonal)
- **Sculpt paramétrico**: deformar sólidos CAD manteniendo historia paramétrica (similar a Fusion 360 freeform)
- **Integración con Hi-Rez/Satin** estable (ya clonado local)
- **Pruebas de exportación STL/OBJ** con slicers reales (Bambu Studio, PrusaSlicer)

### Fase 3 (Diciembre 2026) — Colaboración + AI + Export 3D Print
- **Colaboración real-time**: WebSocket + Core ML para diff de escenas (basado en protocolo de NanoAtlas)
- **AI generativa**: generar texturas PBR desde prompts (vía Core ML on-device, sin API cloud)
- **Export directo a impresoras 3D**: Bambu Lab API, PrusaLink, OctoPrint
- **Suscripción premium**: $4.99/mes desbloquea export STEP/USDZ, simulación, sin ads, AI textures

### Fase 4 (2027) — CAM + Simulación
- **CAM básico**: generación de toolpaths para fresado 3 axis
- **Simulación FEM**: análisis de tensiones simplificado (vía Open Cascade MeshSewing)
- **Plugins/API**: SDK para extensiones de comunidad
- **Versión Android** (Kool engine, Kotlin)

## 5. Modelo de Monetización

| Feature | Free (con ads) | Premium ($4.99/mes) |
|---|---|---|
| Paint 3D + Sculpt | Sí | Sí |
| CAD paramétrico (sketch, constraints, extrude) | Sí | Sí |
| Animación básica | Sí | Sí |
| Export OBJ/STL/glTF | Sí | Sí |
| Export STEP/USDZ | Limitado (5 export/día) | Ilimitado |
| IBL + PBR textures | No (solo preview) | Sí |
| Simulación FEM | No | Sí |
| Colaboración real-time | No | Sí |
| AI texture generation | No | Sí (5 por mes) |
| Sin publicidad | No | Sí |

**Estimación de ingresos**:
- 20K usuarios activos → ~5% premium = 1000 suscriptores × $4.99 = $4,990/mes
- Publicidad: 19K usuarios free, 3 impresiones/día, $8 eCPM promedio = $456/mes
- **Total estimado**: ~$5,446/mes ($65K/año) en equilibrio. Escalable a $200K+/año con 100K usuarios.

## 6. Acciones Inmediatas (Próximos 15 Días)

1. **Completar CSG booleano** usando OCCTSwift (BRepAlgoAPI_Fuse, Common, Cut)
2. **Integrar IBL + environment maps** desde Hi-Rez/Satin local
3. **Implementar PBR shaders** completos en Metal (normal, roughness, metallic, ao)
4. **Verificar compilación** en macOS (Xcode Cloud CI)
5. **Escribir README.md** con features, screenshots, roadmap público

## 7. Conclusión

AppForge Studio está en una posición única: ya tiene lo esencial de CAD + paint + sculpt + animación + export. Para superar a Shapr3D y Fusion 360, el foco debe estar en:
- **Calidad CAD**: CSG booleano, constraints robustos, timeline estable
- **Integración paint-CAD**: poder texturizar modelos paramétricos como ningún otro lo hace
- **Precio disruptivo**: gratis siempre, premium opcional a $4.99/mes
- **Comunidad open-source**: tracción orgánica por ser gratuito y abierto

El mayor riesgo no es técnico sino de marketing: necesitamos visibilidad. La estrategia es lanzar gratis en App Store con ads y roadmaps públicos en GitHub, ganando por diferenciación funcional + precio.
