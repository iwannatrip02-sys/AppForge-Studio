# OCCTSwift — API real verificada (gsdali/OCCTSwift, jun-2026)

Paquete SPM enorme y real (OCCT 8 completo: Document XDE 636KB, DXF/PDF/SVG exporters, SheetMetal, FeatureRecognition, Drawing 2D). Fuente clonable: `git clone --depth 1 https://github.com/gsdali/OCCTSwift.git` para verificar firmas antes de usar.

## ⚠️ VERIFICAR CONTRA EL TAG PINEADO, NO CONTRA HEAD (lección cara, jul-2026)
`Package.swift` usa `from: "1.0.0"` → CI resuelve el ÚLTIMO tag 1.x (hoy **v1.8.8**). El HEAD del clon va POR DELANTE y puede tener refactors que NO existen en el tag. Ejemplo real que rompió CI: en HEAD el writer DXF es un `enum DXFExporter`, pero en **v1.8.8 `writeDXF` vive en `extension Exporter`** → build rojo `cannot find 'DXFExporter' in scope`. Protocolo obligatorio antes de escribir código nuevo contra OCCTSwift:
1. `git -C <clon> fetch --tags --depth 1 && git checkout v1.8.8` (o el tag que resuelva CI — verlo en el log del paso "Resolve SPM dependencies": "Checking out X.Y.Z of package OCCTSwift").
2. Grep la firma EN ESE TAG, no en HEAD.
`swiftc -parse` local NO detecta esto (no resuelve imports). Solo el build de CI lo caza.

## Shape (verificado contra fuente)
- Accesores: `faces() -> [Face]`, `edges() -> [Edge]` — MÉTODOS, no propiedades (`shape.faces` a secas = error "ambiguous"/"used as property").
- Transform: `translated(by: SIMD3<Double>) -> Shape?`, `rotated(axis:angle:) -> Shape?`, `scaled(by: Double) -> Shape?` (SOLO uniforme), `transformed(matrix: [Double]) -> Shape?`. NO existe tipo `Transform`.
- Offset: `offset(by: Double) -> Shape?`, `offsetFace(distance: Double) -> Shape?`.
- Features: `filleted(radius:)`, `chamfered(distance:)`, `shelled(thickness:)`, `shelled(thickness:openFaces:)`, `extruded(by: SIMD3<Double>)`, `localPrism(direction:)`, `withPrism(profile:direction:height:fuse:)`, `draftPrism(...)`, `prismUntilFace(...)` — todos devuelven `Shape?`.
- Booleanos: operadores `+ - &` devuelven `Shape?`. TAMBIÉN método `subtracting(_ other: Shape, fuzzyValue: Double = 0, glue: BooleanGlue = .off, ...) -> Shape?` (usado por los tests propios de OCCTSwift).
- Primitivas: `box(width:height:depth:) -> Shape?`, `box(origin: SIMD3<Double>, width:height:depth:) -> Shape?`, `cylinder(radius:height:) -> Shape?` (eje Z).
- IO estático: `load(from:)`, `loadSTEP/loadBREP/loadSTL/loadOBJ/loadIGES(from:|fromPath:)` (throws, devuelven Shape NO opcional), `loadGLTF(from:) -> Shape?`.
- `brepData(withTriangles:withNormals:) throws -> Data`. NO existe `fromBrep(Data)` — usar `loadBREP(from: url)`.
- Mesh: `mesh(linearDeflection:angularDeflection:) -> Mesh?` (Mesh OCCT: vertices [SIMD3<Float>], normals, indices [UInt32]). NO existe `triangulate()`.

GOTCHA: las primitivas (box/cylinder/sphere...) están CENTRADAS en el origen — box(2,2,2) ocupa [-1,1]³, su cara superior está en z=1 (verificado por test de picking).

## Face
`normal: SIMD3<Double>?`, `outerWire`, `bounds`, `isPlanar`, `area(tolerance:)`, `surfaceType`, curvaturas, `project(point:)`.

## Exporter (static, enum `Exporter`) — @v1.8.8
`writeSTEP/writeSTL/writeIGES/writePLY/writeOBJ/writeBREP`, `writeGLTF(shape:to:binary:deflection:)` (binary:true = GLB). NO existe `writeGLB`.
**DXF (en `extension Exporter`, NO `DXFExporter`):** `Exporter.writeDXF(drawing: Drawing, to: URL, deflection: Double = 0.1) throws` y `Exporter.writeDXF(shape: Shape, to: URL, viewDirection: SIMD3<Double> = (0,0,1), deflection: Double = 0.1) throws`. Writer de bajo nivel: `public final class DXFWriter` (addLine/addPolyline/addCircle/addArc/addText/write). Existe también `PDFExporter.swift`.

## Drawing 2D (`public final class Drawing`) — @v1.8.8
Fábricas de vista ortográfica (devuelven `Drawing?`): `Drawing.topView(of:)`, `frontView(of:)`, `sideView(of:)`, `isometricView(of:)`, `project(_ shape:, direction:)`, `projectFast(...)`. Aristas: `visibleEdges/hiddenEdges/outlineEdges: Shape?`, `edges(ofType:) -> Shape?`. Dimensiones/anotaciones: `addLinearDimension`, `addRadialDimension`, `addDiameterDimension`, `addAngularDimension`, `addOrdinateDimensions`, `addCentreLine`, `addCentermark`, `addBalloon`, `addHatch`.

## FeatureRecognition (AAG) — @v1.8.8
- `Shape.buildAAG() -> AAG`, `Shape.detectPocketsAAG() -> [PocketFeature]` (= buildAAG().detectPockets()).
- `class AAG`: `init(shape:)`, `nodes: [AAGNode]`, `edges: [AAGEdge]`, `neighbors(of:)`, `edge(between:and:)`, `concaveNeighbors(of:)`, `convexNeighbors(of:)`.
- `extension AAG`: `detectPockets() -> [PocketFeature]`, `detectHoles() -> [(faceIndex: Int, radius: Double, depth: Double)]`.
- `struct PocketFeature`: `floorFaceIndex: Int`, `wallFaceIndices: [Int]`, `zLevel: Double`, `bounds`, `isOpen: Bool`, `depth: Double` (computed).
- Oráculo probado (test propio de OCCTSwift): box(10) → AAG 6 nodos/12 aristas, cada cara 4 vecinos; box(20) − box(origin:(5,5,10),10,10,15) → `detectPocketsAAG().count >= 1`, depth>0, walls no vacías. `detectHoles` NO tiene test propio (no apostar conteos).

## En el proyecto
- `typealias CADShape = OCCTSwift.Shape` en `Sources/CSG/Shape.swift` — usar CADShape evita `import OCCTSwift` por archivo. Pero `Drawing`/`Exporter`/`AAG` SÍ requieren `import OCCTSwift`.
- `OCCTBridge` (Sources/Services) = puente Shape→Mesh propio; `OCCTEngine.shared` = wrapper de primitivas/booleanos. Ambos compilan = superficie de API confiable.
- Fase C: `DrawingExportService` (DXF) y `FeatureRecognitionService` (AAG) en Sources/Services — servicios delgados sobre esta API.
- Regla: NUNCA llamar API de OCCTSwift no verificada — clonar el paquete, CHECKOUT DEL TAG PINEADO, y grep de la firma primero (histórico de sesiones que escribieron contra API imaginaria / contra HEAD equivocado).
