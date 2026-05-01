# Decisiones Arquitectónicas

## 2026-04-29: Pipeline CI/CD Windows -> iPad
**Contexto:** Solo se dispone de PC Windows para desarrollo y iPad como dispositivo de prueba. No hay Mac.
**Decision:** Adoptar GitHub Actions + AltStore como pipeline de compilacion e instalacion.
- Workflow build-ios.yml usa runner macos-14 (gratuito) para compilar con Xcode 15.4
- .ipa sin firma (CODE_SIGNING_ALLOWED=NO) para distribucion personal via AltStore
- Apple ID gratuito: firma valida 7 dias, AltStore autorefresca si el PC esta encendido
- Alternativa TrollStore descartada: iPadOS 26+ no compatible
- OCCTSwift no puede incluirse en el build hasta que exista como Swift Package Manager package

## 2026-04-13: Arquitectura CAD + Sculpt
Ver docs/arquitectura_cad_sculpt.md

## 2026-04-13: Satin como motor de render
Se adopto Satin v0.3.0 como framework Metal para SwiftUI. Alternativa SceneKit descartada por menor control sobre shaders.

## 2026-04-13: OCCT como motor CAD
Se adopto OCCTSwift (bindings Swift para Open CASCADE Technology) para operaciones booleanas, fillet, extrude, revolve. Alternativa SceneKit descartada por falta de CAD parametrico.
## 2026-04-30 06:44 UTC - Bug Fix: Vertex Count Mismatch
**Problema:** SatinMesh.swift:26 y Model3D.swift:23,36 calculaban `vertexCount = vertices.count / 8`, pero PaintRenderer configura stride de 13 floats (pos:4 + normal:3 + tex:2 + color:4). Impacto: Metal dibujaba ~62% de vertices reales.
**Fix:** Cambiado divisor de 8 a 13 en 3 ubicaciones (SatinMesh.swift x1, Model3D.swift x2). Verificado con findstr.

## 2026-04-30 12:13 UTC - Conexion AnimationEngine-SatinRenderer
**Contexto:** Se necesitaba playback real de animaciones 3D en la app. AnimationEngine tenia keyframes pero no estaba conectado al render loop.
**Decision:** Implementar evaluate(at:) en AnimationEngine con interpolacion de keyframes (posicion/rotacion/escala usando simd_mix, simd_quatf y matrices TRS). Integrar en SatinRenderer.update() con deltaTime via CACurrentMediaTime.

## 2026-05-01 02:25 UTC - ModelCacheService con memoria + disco
**Contexto:** ModelLoadService cargaba modelos desde MDLAsset cada vez sin cache, causando recarga en cambios de modo.
**Decision:** Implementar ModelCacheService con dos niveles: NSCache en memoria (50 objetos, 128MB limite) y cache en disco con serializacion JSON de vertices/indices. Integracion pendiente con ModelLoadService.
- Cache key: URL absoluta del modelo
- Primitivas generadas (box/sphere/cylinder/plane) no se cachean
- Serializacion: VertexCacheCodable con vertices + indices, restore via Model.setBuffers
