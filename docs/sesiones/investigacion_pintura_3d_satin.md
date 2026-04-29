# Investigación: Sistema de Pintura 3D en Tiempo Real para iOS con Satin + Metal

---

## 1. Resumen Ejecutivo

Este documento investiga cómo implementar un sistema de pintura 3D en tiempo real sobre mallas
3D en iOS usando el framework **Satin** (github.com/Hi-Rez/Satin, basado en Metal de Apple).
Se analiza la API de Satin, las técnicas de texture painting/vertex painting con Metal shaders,
el ray picking, la arquitectura necesaria y la exportación a formatos 3D.

---

## 2. Satin Framework — Análisis Profundo

### 2.1 Estado del Proyecto

| Aspecto | Detalle |
|---------|---------|
| Repositorio | github.com/Hi-Rez/Satin (archivado Abr 2025, original: mattrajca/Satin) |
| Estrellas | ~844 |
| Licencia | MIT |
| Creador | Reza Ali (Hi-Rez) |
| Lenguajes | Swift 67.8%, Metal 17.3%, ObjC++ 12.9% |
| Plataformas | macOS 14.0+, iOS 17.0+, visionOS 2.0+ |
| Instalación | Swift Package Manager |

### 2.2 Estructura del Código Fuente

```
Sources/Satin/
├── AR/                  # Integración con ARKit
├── Animation/           # Sistemas de animación
├── Buffers/             # Vertex/Index/Uniform buffers
├── CameraControllers/   # Cámaras orbit, FPS, etc.
├── Cameras/             # PerspectiveCamera, OrthographicCamera
├── Codable/             # Serialización
├── Compute/             # Sistemas de compute shaders
│   ├── BufferComputeSystem.swift
│   ├── ComputeProcessor.swift
│   ├── ComputeSystem.swift
│   ├── TextureComputeProcessor.swift
│   ├── TextureComputeSystem.swift   ← IMPORTANTE para painting
│   └── TessellationProcessor.swift
├── Constants/           # Constantes de la API Metal
├── Converters/          # YCbCrToRGBConverter
├── Core/                # Renderer.swift, Context
├── Extensions/          # Extensions útiles
├── Generators/          # BRDF LUT, IBL
├── Geometry/            # Box, Sphere, IcoSphere, Plane, Quad, etc.
├── Lights/              # Sistemas de iluminación
├── Materials/           # BasicColor, BasicTexture, PBR, etc.
├── Objects/             # Mesh, InstancedMesh, TessellationMesh, Submesh
├── Parameters/          # Sistema dinámico de parámetros/uniformes
├── Pipelines/           # Pipeline caches (render & compute)
├── Protocols/           # Shader, Geometry protocol, etc.
├── Raycast/             # Raycasting con BVH
├── Renderer/            # Implementación del renderer
├── Shaders/             # Shaders Swift + cache system
├── Shadows/             # Sistema de sombras
├── Text/                # SDF Text Rendering
├── Types/               # Vertex, LightData, ShadowData
├── Utilities/           # Utilidades varias
└── Views/               # MetalView, SatinMetalView (SwiftUI)
```

### 2.3 Componentes Clave para Painting

#### 2.3.1 Mesh (Objects/Mesh.swift)
```swift
open class Mesh: Object, Renderable {
    public var geometry: Geometry?
    public var material: Material?
    public var materials: [Material] { ... }
    // preDraw hook: permite ejecutar código antes de dibujar
    public var preDraw: ((MTLRenderCommandEncoder) -> Void)?
}
```

#### 2.3.2 Geometry (Geometry/SatinGeometry.swift)
La geometría usa un buffer interleaved con el siguiente layout (SatinVertex):

| Offset | Tipo | Atributo |
|--------|------|----------|
| 0 | float4 (16 bytes) | Position |
| 16 | float4 (16 bytes) | Normal |
| 32 | float2 (8 bytes) | Texcoord (UV) |
| **Total** | **40 bytes** | |

```swift
open class SatinGeometry: Geometry {
    public internal(set) var geometryData: GeometryData
    // generateGeometryData() → crea GeometryData con vertices + indices
    // setFrom(geometryData:) → configura buffers a partir de GeometryData
}
```

#### 2.3.3 Materiales Relevantes

**BasicTextureMaterial** — crucial para mostrar la textura pintada:
```swift
open class BasicTextureMaterial: BasicColorMaterial {
    public var texture: MTLTexture?        // La textura a mostrar
    public var sampler: MTLSamplerState?    // Sampler (linear por defecto)
    public var flipped: Bool = false        // Flip Y

    public init(texture: MTLTexture?, sampler: MTLSamplerState? = nil)
    // bindTexture(_ renderEncoder:) — vincula la textura al fragment shader
    // bindSampler(_ renderEncoder:) — vincula el sampler
}
```

#### 2.3.4 Sistema de Shaders

```swift
open class SourceShader: Shader {
    public var pipelineURL: URL           // URL al archivo .metal
    public var source: String?            // Código fuente del shader
    public var live: Bool = false         // Live coding: recompila en caliente
    // MetalFileCompiler — compila shaders en runtime
    // ShaderPipelineCache — cachea pipelines
}
```

#### 2.3.5 Sistema de Compute (TextureComputeSystem)

Ideal para implementar painting en GPU:
```swift
open class TextureComputeSystem: ComputeSystem {
    public var textureDescriptors: [MTLTextureDescriptor]  // Descripción de texturas
    public var srcTexture: MTLTexture?    // Textura fuente (lectura)
    public var dstTexture: MTLTexture?    // Textura destino (escritura)
    public var feedback: Bool             // Double-buffering para painting incremental
    
    // Ciclo: resetTextures() → update(commandBuffer:) → encode()
    open func bind(computeEncoder:iteration:) -> Int
    open func setupTextures()
}
```

---

## 3. Raycasting (Picking) en Satin

### 3.1 API de Raycasting

Satin incluye raycasting con BVH (Bounding Volume Hierarchy):

```swift
// Punto de entrada principal
public func raycast(
    camera: Camera,
    coordinate: simd_float2,     // Coordenada de pantalla (touch)
    objects: [Object],
    options: RaycastOptions = .recursiveAndVisible
) -> [RaycastResult]

// También disponible:
public func raycast(origin: simd_float3, direction: simd_float3, ...)
public func raycast(ray: Ray, objects: [Object], ...)
```

### 3.2 RaycastResult

```swift
public struct RaycastResult {
    public let barycentricCoordinates: simd_float3  // Coordenadas baricéntricas en el triángulo
    public let distance: Float                       // Distancia desde el origen del rayo
    public let normal: simd_float3                   // Normal en el punto de impacto
    public let position: simd_float3                 // Posición en mundo del impacto
    public let primitiveIndex: UInt32                // Índice del triángulo
    public let object: Object                        // Objeto impactado
    public let submesh: Submesh?                     // Submesh (si aplica)
    public let instance: Int                         // Instancia (si aplica)
}
```

### 3.3 Cálculo de UV desde RaycastResult

Para obtener la coordenada UV exacta del punto de impacto:

```swift
func interpolateUV(from result: RaycastResult, geometry: Geometry) -> simd_float2 {
    let primitiveIndex = Int(result.primitiveIndex)
    let indices = geometry.indexData  // indices del triángulo
    let uvs = geometry.uvData          // UVs de todos los vértices
    
    let i0 = indices[primitiveIndex * 3]
    let i1 = indices[primitiveIndex * 3 + 1]
    let i2 = indices[primitiveIndex * 3 + 2]
    
    let uv0 = uvs[i0]
    let uv1 = uvs[i1]
    let uv2 = uvs[i2]
    
    let b = result.barycentricCoordinates
    return b.x * uv0 + b.y * uv1 + b.z * uv2
}
```

---

## 4. Técnicas de Pintura sobre Mallas 3D con Metal

### 4.1 Enfoque 1: Texture Painting en CPU

```
Touch → Raycast → Obtener UV → Modificar UIImage/raw pixels → Subir textura a GPU
```

**Ventajas:** Simple de implementar, fácil depuración.
**Desventajas:** Lento, bloquea el UI thread con texturas grandes, no es tiempo real.

**Implementación:**
```swift
func paintCPU(raycastResult: RaycastResult, geometry: Geometry, 
              texture: inout MTLTexture, color: simd_float4, radius: Float) {
    let uv = interpolateUV(from: raycastResult, geometry: geometry)
    let width = texture.width
    let height = texture.height
    
    // Mapear UV a coordenadas de píxel
    let px = Int(uv.x * Float(width))
    let py = Int(uv.y * Float(height))
    
    // Crear region de pintura circular
    let region = MTLRegionMake2D(px - Int(radius), py - Int(radius), 
                                  Int(radius * 2), Int(radius * 2))
    var pixels = [UInt8](repeating: 0, count: region.size.width * region.size.height * 4)
    texture.getBytes(&pixels, bytesPerRow: width * 4, from: region, mipmapLevel: 0)
    
    // Modificar pixels...
    // Subir textura actualizada
    texture.replace(region: region, mipmapLevel: 0, withBytes: pixels, 
                    bytesPerRow: width * 4)
}
```

### 4.2 Enfoque 2: Texture Painting en GPU (Compute Shader) — RECOMENDADO

```
Touch → Raycast → Obtener UV + triángulo → Dispatch compute kernel → GPU pinta en tiempo real
```

**Ventajas:** Rendimiento en tiempo real, procesamiento paralelo, no bloquea CPU.
**Desventajas:** Más complejo, requiere shaders Metal.

**Metal Compute Kernel para Painting:**

```metal
#include <metal_stdlib>
using namespace metal;

kernel void paintTexture(
    texture2d<float, access::read_write> paintTex [[texture(0)]],
    constant float2 &paintUV [[buffer(0)]],
    constant float4 &paintColor [[buffer(1)]],
    constant float &paintRadius [[buffer(2)]],
    constant float2 &texSize [[buffer(3)]],
    uint2 gid [[thread_position_in_grid]]
) {
    float2 uv = float2(gid) / texSize;
    float dist = distance(uv, paintUV);

    if (dist < paintRadius) {
        float4 existing = paintTex.read(gid);
        float alpha = 1.0 - smoothstep(0.0, paintRadius, dist);
        float4 brushColor = paintColor * alpha;
        float4 result = mix(existing, brushColor, brushColor.a);
        paintTex.write(result, gid);
    }
}
```

**Uso con TextureComputeSystem (Satin):**

```swift
class PaintComputeSystem: TextureComputeSystem {
    var paintUV: simd_float2 = .zero
    var paintColor: simd_float4 = .init(1, 0, 0, 1)
    var paintRadius: Float = 0.01

    override func bind(computeEncoder: MTLComputeCommandEncoder, 
                       iteration: Int) -> Int {
        var offset = super.bind(computeEncoder: computeEncoder, iteration: iteration)
        computeEncoder.setBytes(&paintUV, length: MemoryLayout<simd_float2>.size, index: offset)
        offset += 1
        computeEncoder.setBytes(&paintColor, length: MemoryLayout<simd_float4>.size, index: offset)
        offset += 1
        computeEncoder.setBytes(&paintRadius, length: MemoryLayout<Float>.size, index: offset)
        offset += 1
        return offset
    }
}
```

### 4.3 Enfoque 3: Vertex Painting

Útil para mallas de baja resolución o cuando no se quiere usar texturas.

**Metal Vertex Shader con color de vértice:**
```metal
struct VertexIn {
    float4 position [[attribute(0)]];
    float4 normal   [[attribute(1)]];
    float2 texcoord [[attribute(2)]];
    float4 color    [[attribute(3)]];  // ← Color por vértice
};
```

**Actualización de colores de vértice:**
```swift
func paintVertex(geometry: Geometry, raycastResult: RaycastResult, 
                 color: simd_float4, radius: Float) {
    let primitiveIndex = Int(raycastResult.primitiveIndex)
    // Actualizar vertex buffer con colores modificados
    // El radio se mide en distancia 3D, no UV
}
```

### 4.4 Comparación de Técnicas

| Técnica | Rendimiento | Calidad | Complejidad | Uso de GPU | Ideal para |
|---------|-------------|---------|-------------|------------|------------|
| CPU Texture Painting | Bajo | Alta | Baja | Mínimo | Prototipos, texturas pequeñas |
| GPU Compute Painting | Alto | Alta | Media | Alto | **Producción, tiempo real** |
| Vertex Painting | Alto | Baja | Baja | Bajo | Mallas low-poly, debug |
| Fragment Shader Painting | Medio | Media | Alta | Medio | Efectos dinámicos temporales |

---

## 5. Arquitectura Propuesta

### 5.1 Diagrama de Flujo

```
┌─────────────────────────────────────────────────────────────────────┐
│  UI Layer (SwiftUI)                                                  │
│  ┌─────────────────────────────────────────────────────────────────┐ │
│  │  SatinMetalView (MTKView + Gesture Recognizers)                 │ │
│  │  • onTouchBegan / onTouchMoved / onTouchEnded                   │ │
│  └──────────────────────────┬──────────────────────────────────────┘ │
├─────────────────────────────┼────────────────────────────────────────┤
│  Painting Renderer           │                                       │
│  ┌──────────────────────────▼──────────────────────────────────────┐ │
│  │  PaintingRenderer: MetalViewRenderer                             │ │
│  │                                                                  │ │
│  │  func setup() → crear escena, cámara, malla, textura             │ │
│  │  func update() → actualizar animaciones                          │ │
│  │  func draw() → renderizar escena                                 │ │
│  │                                                                  │ │
│  │  Al recibir touch:                                                │ │
│  │   1. Convertir touch a coordenada normalizada                    │ │
│  │   2. raycast(camera:coordinate:objects:)                         │ │
│  │   3. Si hay hit: dispatch compute shader de painting             │ │
│  └──────────────────────────┬──────────────────────────────────────┘ │
├─────────────────────────────┼────────────────────────────────────────┤
│  Rendering Pipeline          │                                       │
│  ┌──────────────────────────▼──────────────────────────────────────┐ │
│  │  Renderer (Satin)                                                │ │
│  │  • Administra scene graph + materiales + luces                   │ │
│  │  • Compone múltiples render passes                               │ │
│  │  • Maneja sombras, PBR, post-processing                          │ │
│  └────────────┬─────────────────────────────────┬──────────────────┘ │
│               │                                 │                    │
│  ┌────────────▼──────────┐      ┌───────────────▼──────────────────┐│
│  │  Scene Objects         │      │  PaintComputeSystem              ││
│  │  • Mesh objetivo       │      │  (TextureComputeSystem)          ││
│  │  • Gizmo/pincel 3D     │      │  • Dispatch compute kernel       ││
│  │  • Luces               │      │  • Double-buffered texture       ││
│  └────────────────────────┘      │  • Brush state (UV, color,      ││
│                                  │    radius, hardness, opacity)    ││
│                                  └──────────────────────────────────┘│
└─────────────────────────────────────────────────────────────────────┘
```

### 5.2 Estructura de Clases Propuesta

```swift
// MARK: - Renderer Principal
final class PaintingRenderer: MetalViewRenderer {
    // Scene
    lazy var scene: Object = { ... }
    lazy var camera: PerspectiveCamera = { ... }
    lazy var renderer: Renderer = { ... }

    // Target mesh
    var targetMesh: Mesh
    var paintTexture: MTLTexture

    // Compute painting
    var paintCompute: PaintComputeSystem

    // Brush state
    var brushColor: simd_float4 = .init(1, 0, 0, 1)
    var brushRadius: Float = 0.02
    var brushHardness: Float = 0.8
    var brushOpacity: Float = 1.0

    // Touch handling
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: mtkView)
        let normalized = simd_float2(
            Float(location.x / mtkView.bounds.width),
            Float(location.y / mtkView.bounds.height)
        )
        paint(at: normalized)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        // Interpolación entre puntos para trazos continuos
    }

    func paint(at coordinate: simd_float2) {
        let results = raycast(
            camera: camera,
            coordinate: coordinate,
            objects: [targetMesh]
        )

        guard let hit = results.first else { return }
        guard let geometry = targetMesh.geometry else { return }

        let uv = interpolateUV(from: hit, geometry: geometry)

        // Dispatch compute shader
        paintCompute.paintUV = uv
        paintCompute.paintColor = brushColor
        paintCompute.paintRadius = brushRadius
        paintCompute.update(commandBuffer: currentCommandBuffer)
    }
}

// MARK: - Custom Live-Coded Shader Material
final class PaintableTextureMaterial: BasicTextureMaterial {
    override init(texture: MTLTexture?, sampler: MTLSamplerState? = nil) {
        super.init(texture: texture, sampler: sampler)
        // Usar shader personalizado con UV + textura
    }
}
```

### 5.3 Flujo de Datos

```
Touch Event
  │
  ▼
MTKView coordinates → Normalized coordinates [0..1]
  │
  ▼
raycast(camera:coordinate:objects:) → Satin's BVH acceleration
  │
  ├── No hit → retornar
  │
  ▼ Hit detected
RaycastResult {
    primitiveIndex: índice del triángulo
    barycentricCoordinates: coordenadas baricéntricas
    position: punto de impacto en mundo
    normal: normal de la superficie
}
  │
  ▼
Interpolate UV = barycentric.x * uv[tri[0]] 
                + barycentric.y * uv[tri[1]] 
                + barycentric.z * uv[tri[2]]
  │
  ▼
PaintComputeSystem.update(commandBuffer:)
  │
  ▼
Metal Compute Kernel (parallel over texture pixels)
  │
  ▼
srcTexture ↔ dstTexture (double-buffered feedback)
  │
  ▼
BasicTextureMaterial.texture = paintCompute.dstTexture
  │
  ▼
Renderer.draw() → Fragment Shader muestra textura pintada
```

---

## 6. Implementación Detallada de Componentes

### 6.1 Configuración de la Textura Pintable

```swift
func createPaintTexture(device: MTLDevice, size: Int = 2048) -> MTLTexture {
    let descriptor = MTLTextureDescriptor.texture2DDescriptor(
        pixelFormat: .rgba8Unorm,
        width: size,
        height: size,
        mipmapped: false
    )
    descriptor.usage = [.shaderRead, .shaderWrite, .renderTarget]
    descriptor.storageMode = .private

    guard let texture = device.makeTexture(descriptor: descriptor) else {
        fatalError("Failed to create paint texture")
    }
    texture.label = "Paint Texture"

    // Inicializar con blanco
    let initialColor = MTLRegionMake2D(0, 0, size, size)
    let blankPixels = [UInt8](repeating: 255, count: size * size * 4)
    texture.replace(region: initialColor, mipmapLevel: 0,
                    withBytes: blankPixels, bytesPerRow: size * 4)

    return texture
}
```

### 6.2 Pincel con Interpolación entre Puntos (Trazos Continuos)

```swift
var lastUV: simd_float2?
var lastHit: RaycastResult?

func paintStroke(from last: simd_float2, to current: simd_float2,
                 geometry: Geometry, compute: PaintComputeSystem) {
    let steps = Int(ceil(distance(current, last) / (brushRadius * 0.5)))
    for i in 0...steps {
        let t = Float(i) / Float(steps)
        let interpolatedUV = mix(last, current, t)
        compute.paintUV = interpolatedUV
        compute.update(commandBuffer: commandBuffer)
    }
}
```

### 6.3 Múltiples Capas de Pintura (Undo/Redo)

```swift
class PaintLayerManager {
    private var layers: [MTLTexture] = []
    private var currentLayerIndex: Int = 0
    private let maxLayers: Int = 32

    func pushLayer(texture: MTLTexture) {
        // Copiar textura actual a nueva capa
    }

    func undo() {
        // Retroceder en el historial de capas
    }

    func redo() {
        // Avanzar en el historial de capas
    }

    func compositeLayers() -> MTLTexture {
        // Compute kernel que compone todas las capas
    }
}
```

### 6.4 Visualización del Pincel en 3D (Gizmo)

```swift
class BrushGizmo {
    let mesh: Mesh  // Círculo o disco que sigue la superficie

    func update(hit: RaycastResult) {
        position = hit.position
        // Orientar para que apunte en dirección de la normal
        lookAt(hit.position + hit.normal)
    }
}
```

### 6.5 Custom Shader para Pintura con Textura

**.metal file (Shader personalizado):**

```metal
#include <metal_stdlib>
using namespace metal;

struct VertexIn {
    float4 position [[attribute(0)]];
    float4 normal   [[attribute(1)]];
    float2 texcoord [[attribute(2)]];
};

struct VertexOut {
    float4 position [[position]];
    float2 texcoord;
};

vertex VertexOut paintVertex(VertexIn in [[stage_in]],
                             constant float4x4 &modelViewProjection [[buffer(0)]])
{
    VertexOut out;
    out.position = modelViewProjection * in.position;
    out.texcoord = in.texcoord;
    return out;
}

fragment float4 paintFragment(VertexOut in [[stage_in]],
                              texture2d<float> paintTex [[texture(0)]],
                              sampler samp [[sampler(0)]])
{
    return paintTex.sample(samp, in.texcoord);
}
```

---

## 7. Exportación a STL/OBJ

### 7.1 Evaluación de Alternativas

| Herramienta | Soporte iOS | Formatos | Facilidad | Notas |
|-------------|-------------|----------|-----------|-------|
| **ModelIO (Apple)** | ✅ Nativo | OBJ, STL, USD, ABC | Alta | Framework oficial, integrado con Metal |
| Assimp | ⚠️ Requiere C++ | 40+ formatos | Baja | Needs bridging header, no SPM |
| Satin | ⚠️ Parcial | No exporta directamente | — | Tiene GeometryData, no export |

### 7.2 Exportación con ModelIO (Recomendado)

```swift
import ModelIO
import MetalKit

func exportOBJ(mesh: Mesh, texture: MTLTexture, url: URL) throws {
    let device = MTLCreateSystemDefaultDevice()!

    // 1. Crear MDLMesh desde la geometría de Satin
    let allocator = MTKMeshBufferAllocator(device: device)
    let mdlMesh = MDLMesh(
        vertexBuffer: mesh.geometry!.vertexBuffer,
        vertexCount: mesh.geometry!.vertexCount,
        descriptor: mesh.geometry!.vertexDescriptor,
        submeshes: mesh.geometry!.submeshes
    )

    // 2. Asignar material con textura pintada
    let material = MDLMaterial(name: "paint", scatteringFunction: MDLScatteringFunction())
    let textureProperty = MDLMaterialProperty(
        name: "baseColor",
        semantic: .baseColor,
        texture: texture
    )
    material.setProperty(textureProperty)
    mdlMesh.submeshes?.first?.material = material

    // 3. Exportar a OBJ/STL
    let asset = MDLAsset(bufferAllocator: allocator)
    asset.add(mdlMesh)
    try asset.export(to: url)
}
```

### 7.3 Exportación de la Textura Pintada

```swift
func exportTexture(_ texture: MTLTexture, to url: URL) {
    let ciImage = CIImage(mtlTexture: texture, options: nil)!
    let context = CIContext()
    try? context.writePNGRepresentation(
        of: ciImage,
        to: url,
        format: .RGBA8,
        colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!
    )
}
```

### 7.4 Satin GeometryData → ModelIO

Satin no tiene conversión directa a ModelIO. Se necesita un adaptador:

```swift
extension MDLMesh {
    convenience init(satinGeometry geometry: SatinGeometry, 
                     device: MTLDevice, allocator: MTKMeshBufferAllocator) {
        // Construir MDLMeshVertexDescriptor desde los attributes
        // Crear MDLMeshBuffer desde el vertex buffer de Satin
        // Inicializar con submeshes
        self.init(...)
    }
}
```

---

## 8. Referencias a APIs Específicas de Metal y Satin

### 8.1 Metal APIs Clave

| API | Uso en Painting |
|-----|-----------------|
| `MTLTexture.write(_:at:)` | Escribir píxeles desde compute shader |
| `MTLTexture.read(_:)` | Leer píxeles existentes (blending) |
| `MTLComputeCommandEncoder.dispatchThreads(...)` | Ejecutar kernel de painting |
| `MTLRenderCommandEncoder.setFragmentTexture(...)` | Mostrar textura pintada |
| `MTLBuffer.contents()` | Actualizar vertex colors (CPU path) |
| `MTLTexture.replace(region:mipmapLevel:withBytes:...)` | CPU → GPU texture upload |
| `MTKView.currentDrawable.texture` | Render target final |

### 8.2 Satin APIs Clave

| Clase / Función | Uso |
|-----------------|-----|
| `Mesh(geometry:material:)` | Malla a pintar |
| `BasicTextureMaterial(texture:)` | Material que muestra la textura pintada |
| `raycast(camera:coordinate:objects:)` | Detectar qué triángulo tocó el usuario |
| `RaycastResult.barycentricCoordinates` | Interpolar UVs |
| `RaycastResult.primitiveIndex` | Saber qué triángulo |
| `TextureComputeSystem` | Compute shader de painting en GPU |
| `SourceShader(pipelineURL:)` | Shader live-codeable para la malla |
| `MetalViewRenderer` | Base para el renderer con callbacks |
| `InterleavedBuffer` | Vertex buffer con Position+Normal+Texcoord |
| `Geometry.vertexBuffer` | Acceso a datos de vértices |
| `Geometry.indexBuffer` | Acceso a índices |

### 8.3 Enlaces de Referencia

- Satin GitHub: https://github.com/Hi-Rez/Satin
- Satin Docs: https://github.com/Hi-Rez/Satin/wiki (offline)
- Metal Shading Language Spec: https://developer.apple.com/metal/Metal-Shading-Language-Specification.pdf
- ModelIO Framework: https://developer.apple.com/documentation/modelio
- Metal Textures Guide: https://developer.apple.com/documentation/metal/textures

---

## 9. Proyectos Existentes y Referencias

### 9.1 Basados en Satin

| Proyecto | Descripción |
|----------|------------|
| Satin (Hi-Rez) | Framework base con ejemplos de raycasting, compute, export |
| SatinPro | Versión Pro (no open source, builds sobre Satin) |
| Satin Examples | Renderers/Basics, Renderers/Compute, Renderers/Customization |

### 9.2 Conceptos Relacionados (no-Satin)

| Proyecto | Técnica | Relevancia |
|----------|---------|------------|
| Procreate (iPad) | Texture painting con Metal | Referencia de UX/performance |
| Substance Painter | 3D texture painting | Arquitectura de capas y pinceles |
| Blender 3D Texture Paint | CPU/GPU hybrid painting | Algoritmos de proyección UV |
| Three.js `Raycaster` | JavaScript ray picking | Concepto similar al de Satin |
| Metal by Example | Compute shader post-processing | Patrones de GPU compute |

### 9.3 Patrones Técnicos Comunes en 3D Painting

1. **Stamp-based painting**: Pinta un "stamp" (círculo, textura) en cada punto de impacto.
2. **Stroke interpolation**: Interpola entre puntos de contacto para trazos suaves.
3. **Projective painting**: Proyecta la pincelada desde la cámara (útil para modelos complejos).
4. **3D brush raymarching**: Pinta siguiendo la dirección de la normal en 3D.
5. **Layer-based compositing**: Capas de pintura con blending modes.

---

## 10. Roadmap de Implementación Sugerido

### Fase 1: Prototipo Básico (1-2 semanas)
- [ ] Configurar proyecto con Satin vía SPM
- [ ] Renderizar malla 3D con BasicTextureMaterial
- [ ] Implementar raycasting sobre la malla
- [ ] Pintar en CPU: modificar UIImage → subir textura
- [ ] Mostrar la textura pintada en tiempo real

### Fase 2: GPU Compute Painting (2-3 semanas)
- [ ] Crear PaintComputeSystem (hereda de TextureComputeSystem)
- [ ] Escribir Metal compute kernel de painting
- [ ] Implementar double-buffering para feedback
- [ ] Agregar interpolación de trazos
- [ ] Brush configurables: radio, dureza, opacidad

### Fase 3: UX y Features (2-3 semanas)
- [ ] Pincel 3D (gizmo) que sigue la superficie
- [ ] Gestos: tap, drag, pinch para radio
- [ ] Selector de color (HSB picker)
- [ ] Undo/redo con capas
- [ ] Preview de pincel en tiempo real

### Fase 4: Exportación (1 semana)
- [ ] Exportar textura pintada como PNG
- [ ] Exportar malla + textura como OBJ (ModelIO)
- [ ] Exportar como USDZ (AR Quick Look)
- [ ] Compartir vía UIActivityViewController

---

## 11. Consideraciones de Rendimiento

### 11.1 Resolución de Textura
| Resolución | Uso de Memoria | Calidad | Rendimiento |
|------------|----------------|---------|-------------|
| 512×512 | ~1 MB | Baja | Excelente |
| 1024×1024 | ~4 MB | Media | Muy bueno |
| 2048×2048 | ~16 MB | Alta | Bueno |
| 4096×4096 | ~64 MB | Muy alta | Regular |

**Recomendación:** 2048×2044 para producción, 1024×1024 para prototipado.

### 11.2 Optimizaciones GPU
- Usar `MTLResourceOptions.storageModePrivate` texturas
- Double-buffering en compute para evitar race conditions
- Batch de pinceladas: acumular varios stamps antes de dispatch
- Mipmaps: no necesarios para painting (solo display)
- Limitar el área de dispatch del compute kernel a la región afectada

### 11.3 Optimizaciones CPU
- Ejecutar raycasting en background thread
- Mantener BVH actualizado solo cuando la geometría cambia
- Usar `MTKView.preferredFramesPerSecond = 60` para painting

---

## 12. Conclusión

Satin es un framework sólido para implementar un sistema de pintura 3D en tiempo real en iOS.
Proporciona:

1. **Raycasting con BVH** ya implementado y optimizado
2. **TextureComputeSystem** para painting en GPU via compute shaders
3. **BasicTextureMaterial** para mostrar texturas pintadas
4. **SourceShader** con live coding para iteración rápida de shaders
5. **Gestión de buffers y texturas** Metal sin boilerplate

La arquitectura recomendada usa **GPU compute shaders** para el painting, con
double-buffering de texturas y raycasting para detección de impacto.

Para exportación, **ModelIO** es la solución nativa recomendada (OBJ, STL, USD),
aunque Satin no incluye export directo: se necesita un adaptador `SatinGeometry → MDLMesh`.

**Limitaciones a considerar:**
- Satin está archivado desde abril 2025 (no habrá nuevas features)
- No incluye exportación a OBJ/STL
- La documentación de la wiki no está disponible
- El sistema de capas/undo debe implementarse desde cero
