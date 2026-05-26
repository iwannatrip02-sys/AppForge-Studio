# CAD Kernel Implementation Plan — AppForge Studio
> Fecha: 2026-05-04 | Fuentes: OCCT 7.9.3, SolveSpace, FreeCAD GCS, OCCTSwift, SolidWorks/Onshape mates

## 1. Kernel CAD: OCCT 7.9.3+ via OCCTSwift

**OCCTSwift** (github.com/gsdali/OCCTSwift) es un wrapper Swift existente para OpenCASCADE Technology que ya tiene:
- Building guide para iOS/macOS (static libraries via Xcode)
- MCP server para integracion
- Viewport Metal para preview (opcional)

**API OCCT confirmadas para iOS:**
- `BRepPrimAPI_MakePrism` — extrusion recta de sketch 2D
- `BRepPrimAPI_MakeRevol` — revolucion de perfil 2D alrededor de eje (angulo parcial o 360 deg)
- `BRepOffsetAPI_MakePipeShell` — sweep/loft con secciones y spine (modos: pseudo-Frenet, binormal constante, normal constante, superficie soporte)
- `BRepAlgoAPI_Fuse/Cut/Common` — booleanas (union, diferencia, interseccion)
- `BRepFilletAPI_MakeFillet` — redondeo de aristas
- `BRepFilletAPI_MakeChamfer` — chaflan de aristas
- `BRepOffsetAPI_MakeThickSolid` — shell (vaciado de solido)
- `BRepPrimAPI_MakeBox/Cylinder/Cone/Sphere` — primitivas parametricas

**Stack de integracion:**
OCCT C++ (.hxx/.cxx) -> static libs (.a) -> XCFramework -> Obj-C++ bridging header -> Swift (OCCTSwift) -> SPM module

## 2. Constraint Solver 2D (Sketch)

**Arquitectura basada en SolveSpace + FreeCAD GCS (PlanGCS):**
- Sistema simbolico de ecuaciones (Newton-Raphson modificado)
- Jacobiano resuelto en minimos cuadrados para sketches subconstrenidos
- Penalty metric para arrastre suave
- Degrees of Freedom tracking (PlanGCS style)
- DAG de dependencias entre constraints

**Implementacion Swift puro (sin OCCT para el solver):**
- Graph DAG con nodos Entity (Point, Line, Circle, Arc) y nodos Constraint
- Newton-Raphson con Sparse Matrix (simd/Accelerate framework vDSP)
- Tipos de constraints 2D: Horizontal, Vertical, Parallel, Perpendicular, Coincident, Distance, Angle, Radius, Diameter, Equal, Tangent, Fix

## 3. Feature Timeline (History)

**SwiftData + Codable protocol FeatureNode:**
@Model class FeatureNode {
    var id: UUID
    var type: FeatureType // sketch, extrude, revolve, fillet, chamfer, shell, boolean
    var parameters: Data // JSON codificado
    var parentId: UUID?
    var children: [FeatureNode]
    var order: Int
    var isSuppressed: Bool
    var cachedBRep: Data? // serializacion BRep OCCT
}
- DAG de dependencias con rollback y recompute
- Recompute solo de features afectados por cambio

## 4. Assembly Mates (11 tipos confirmados)

**Standard Mates (SOLIDWORKS/Onshape):**
1. Coincident — puntos/caras/aristas coinciden
2. Parallel — caras/aristas paralelas
3. Perpendicular — caras/aristas perpendiculares
4. Tangent — cara tangente a otra cara o cilindro
5. Concentric — ejes de cilindros/conos alineados
6. Distance — distancia fija entre caras/aristas
7. Lock — bloqueo completo de grados de libertad
8. Angle — angulo fijo entre caras/aristas

**Mechanical Mates:**
9. Gear — relacion rotacional entre 2 mates rotacionales
10. Rack & Pinion — relacion rotacional+traslacional
11. Screw — rotacion+traslacion con distancia por revolucion

**Implementacion:**
- Swift struct Mate con tipo + referencia a dos entidades + parametros
- Kinematic solver: constraint graph + Newton-Raphson 3D
- Interference detection mediante OCCT BRepAlgoAPI_Common

## 5. Plan de 16 meses (refinado con datos reales)

| Mes | Modulo | OCCT API | Swift |
|-----|--------|----------|-------|
| 1-2 | Build OCCT iOS + primitives + sketch | BRepPrimAPI_MakeBox/Cylinder, BRepBuilderAPI_MakeEdge/Wire/Face | OCCTSwift integration, SketchView |
| 3-4 | Extrude/Revolve/Sweep/Loft + DAG | BRepPrimAPI_MakePrism/Revol, BRepOffsetAPI_MakePipeShell | FeatureNode SwiftData, TimelineView |
| 5-6 | Fillet/Chamfer/Shell/Boolean + surfaces | BRepFilletAPI, BRepAlgoAPI, GeomAPI | UI para seleccion de aristas |
| 7-8 | Constraint solver 2D + sketch parametrico | (no necesita OCCT) | PlanGCS-style Newton-Raphson Swift puro |
| 9-10 | Assembly mates + kinematic solver | BRepAlgoAPI_Common (interference) | Mate types + kinematic DAG |
| 11-12 | 2D Drawings + GD&T + BOM + DXF/PDF | HLRBRep_HLRToShape, TPrsStd_AISPresentation | SwiftUI Canvas + CoreGraphics |
| 13-14 | CAM 2.5D/3D/5-axis + toolpath sim | (CAM externo) | G-code generation + 3D visualization |
| 15-16 | FEA meshing + generative design + API | Netgen/BAMG, CoreML | Metal compute shaders para FEA |

## 6. Diferenciacion sobre Shapr3D + Fusion 360

| Feature | Shapr3D | Fusion 360 | AppForge Studio |
|---------|---------|------------|----------------|
| Kernel | Propietario basico | Propietario (Autodesk) | **OCCT profesional (FreeCAD-level)** |
| Constraints sketch | Solo coincident (2026) | Completo | **10 tipos 2D Newton-Raphson** |
| Timeline parametrica | Basica | Completa | **DAG SwiftData con rollback** |
| Assembly mates | Ninguno | 11+ tipos | **11 tipos Standard+Mechanical** |
| CAM | No | 5-axis (pro) | **2.5D/3D/5-axis con G-code** |
| FEA | No | Static/Thermal/Modal | **Static stress + Metal compute** |
| Generative design | No | Si (Autodesk AI) | **CoreML on-device** |
| Sheet metal | No | Si | Si |
| API publica | No | Si (Fusion API) | **Si, REST + WebSocket** |
| Precio | $299/ano | $545/ano | **$199/ano (target)** |

## 7. Paquetes externos necesarios

1. **gsdali/OCCTSwift** — Swift wrapper para OCCT (kernel CAD)
2. **gsdali/OCCTSwiftScripts** — scripts de build (OCCT iOS .a -> XCFramework)
3. **NeoCogi/constraint-solver** (Rust) — inspiracion algoritmo Newton-Raphson en Swift
4. **SolveSpace C++ solver** — referencia de implementacion (open source)
5. **PlanGCS (FreeCAD)** — referencia de architecture DAG + DOF tracking

## 8. Conclusion

AppForge Studio puede superar a Shapr3D y Fusion 360 en iPad porque:
- OCCT (via OCCTSwift) provee kernel CAD profesional equivalente a FreeCAD
- Constraint solver Swift puro + Newton-Raphson (inspirado en SolveSpace/PlanGCS)
- SwiftData para timeline parametrica DAG con rollback
- 11 tipos de assembly mates (lo que Shapr3D no tiene, y Fusion 360 si)
- Precio disruptivo: $199/ano vs $299 (Shapr3D) y $545 (Fusion 360)
- Toda la profundidad engineering (CAM, FEA, generative design) con UX tactil Shapr3D-level
