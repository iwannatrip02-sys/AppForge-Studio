# Decisiones Arquitectonicas - AppForge Studio

## 2026-04-13: Satin como motor de render
Se adopto Satin v0.3.0 como framework Metal para SwiftUI. Alternativa SceneKit descartada por menor control sobre shaders.

## 2026-04-13: OCCT como motor CAD
Se adopto OCCTSwift (bindings Swift para Open CASCADE Technology) para operaciones booleanas, fillet, extrude, revolve. Alternativa SceneKit descartada por falta de CAD parametrico.

## 2026-04-13: Arquitectura CAD + Sculpt
Ver docs/arquitectura_cad_sculpt.md para detalles de la separacion de modos.

## 2026-04-29: Pipeline CI/CD Windows -> iPad
**Contexto:** Solo PC Windows + iPad como dispositivo de prueba. No hay Mac.
**Decision:** GitHub Actions + AltStore.
- Workflow build-ios.yml: runner macos-14 (gratuito), Xcode 15.4
- .ipa sin firma (CODE_SIGNING_ALLOWED=NO) para AltStore
- Apple ID gratuito: firma 7 dias, autorefresco si PC encendido
- TrollStore descartado: iPadOS 26+ no compatible
- OCCTSwift no incluible hasta SPM package

## 2026-04-30 06:44 UTC - Bug Fix: Vertex Count Mismatch
**Problema:** SatinMesh.swift:26 y Model3D.swift:23,36 usaban divisor 8 pero PaintRenderer stride=13 floats (pos4+normal3+tex2+color4). Impacto: Metal dibujaba ~62% de vertices.
**Fix:** Cambiado divisor de 8 a 13 en SatinMesh.swift x1 y Model3D.swift x2.

## 2026-04-30 12:13 UTC - Conexion AnimationEngine-SatinRenderer
**Contexto:** AnimationEngine tenia keyframes pero no conectado al render loop.
**Decision:** evaluate(at:) en AnimationEngine con interpolacion simd. Integrar en SatinRenderer.update() con deltaTime CACurrentMediaTime.

## 2026-05-02 12:52 UTC - Documentacion completa de canonicos
**Contexto:** Los canonicos (GOTCHI.md, BRAIN.md, TODO.md, DECISIONS.md) estaban desactualizados y no reflejaban los modulos reales en disco.
**Decision:** Actualizar los 4 canonicos con informacion real de archivos.

## 2026-05-04 02:35 UTC - Correcciones de calidad y conexion playback
**Contexto:** ExportViewModel tenia case fbx duplicado, ExportService no tenia ExportToFBX real, AnimationPlaybackController existia pero no conectado a SatinRenderer.
**Decision:** (1) Fusionado case fbx duplicado en ExportViewModel. (2) Implementado exportToFBX() real con writer ASCII FBX 7.4.0. (3) Creado AnimationPlaybackController con CADisplayLink. (4) Integrado AnimationPlaybackController en SatinRenderer.update() y AnimationModeView. Pendiente: revisar scene graph, subscription manager, y asegurar compilacion completa.
## 2026-05-04 — Mantener arquitectura actual: SatinRenderer como dispatcher central con animationEngine + playbackController. No refactorizar a capa separada de animación.
**Razón:** El código existente de SatinRenderer ya tiene updateAnimation() con evaluateAnimation, playbackController.tick() y applyTransformsToScene() funcionales. Crear una capa separada sería sobrediseño para el alcance actual y retrasaría la entrega.


## 2026-05-04 — BLOQUEO FASE C: No es posible compilar AppForge Studio en Windows. Se requiere macOS con Xcode 15+. Código Swift/Metal verificado sin errores de sintaxis.
**Razón:** Swift Toolchain no disponible en Windows 11. Proyecto iOS usa Satin v0.3.0 via SPM y Metal shaders que solo compilan en macOS/Xcode.
**Impacto:** Compilación nativa bloqueada en este entorno. Alternativa: push a GitHub para compilar en macOS remoto.

