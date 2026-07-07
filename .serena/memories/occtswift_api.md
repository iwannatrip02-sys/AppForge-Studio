# OCCTSwift — API real verificada (gsdali/OCCTSwift, jun-2026)

Paquete SPM enorme y real (OCCT 8 completo: Document XDE 636KB, DXF/PDF/SVG exporters, SheetMetal, FeatureRecognition, Drawing 2D). Fuente clonable: `git clone --depth 1 https://github.com/gsdali/OCCTSwift.git` para verificar firmas antes de usar.

## Shape (verificado contra fuente)
- Accesores: `faces() -> [Face]`, `edges() -> [Edge]` — MÉTODOS, no propiedades (`shape.faces` a secas = error "ambiguous"/"used as property").
- Transform: `translated(by: SIMD3<Double>) -> Shape?`, `rotated(axis:angle:) -> Shape?`, `scaled(by: Double) -> Shape?` (SOLO uniforme), `transformed(matrix: [Double]) -> Shape?`. NO existe tipo `Transform`.
- Offset: `offset(by: Double) -> Shape?`, `offsetFace(distance: Double) -> Shape?`.
- Features: `filleted(radius:)`, `chamfered(distance:)`, `shelled(thickness:)`, `shelled(thickness:openFaces:)`, `extruded(by: SIMD3<Double>)`, `localPrism(direction:)`, `withPrism(profile:direction:height:fuse:)`, `draftPrism(...)`, `prismUntilFace(...)` — todos devuelven `Shape?`.
- Booleanos: operadores `+ - &` devuelven `Shape?`.
- IO estático: `load(from:)`, `loadSTEP/loadBREP/loadSTL/loadOBJ/loadIGES(from:|fromPath:)` (throws, devuelven Shape NO opcional), `loadGLTF(from:) -> Shape?`.
- `brepData(withTriangles:withNormals:) throws -> Data`. NO existe `fromBrep(Data)` — usar `loadBREP(from: url)`.
- Mesh: `mesh(linearDeflection:angularDeflection:) -> Mesh?` (Mesh OCCT: vertices [SIMD3<Float>], normals, indices [UInt32]). NO existe `triangulate()`.

## Face
`normal: SIMD3<Double>?`, `outerWire`, `bounds`, `isPlanar`, `area(tolerance:)`, `surfaceType`, curvaturas, `project(point:)`.

## Exporter (static)
`writeSTEP/writeSTL/writeIGES/writePLY/writeOBJ/writeBREP`, `writeGLTF(shape:to:binary:deflection:)` (binary:true = GLB). NO existe `writeGLB`.

## En el proyecto
- `typealias CADShape = OCCTSwift.Shape` en `Sources/CSG/Shape.swift` — usar CADShape evita `import OCCTSwift` por archivo.
- `OCCTBridge` (Sources/Services) = puente Shape→Mesh propio; `OCCTEngine.shared` = wrapper de primitivas/booleanos. Ambos compilan = superficie de API confiable.
- Regla: NUNCA llamar API de OCCTSwift no verificada — clonar el paquete y grep de la firma primero (histórico de sesiones que escribieron contra API imaginaria).
