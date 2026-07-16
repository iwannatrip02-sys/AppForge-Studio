// swift-tools-version:5.9
// SketchKernel — kernel 2D de dibujo (Fase 1, docs/FASE_1_DIBUJO_CONTRATO.md).
// Paquete PURO (sin simd/UIKit/Metal) a propósito: compila y se testea en
// cualquier host (incluido Windows, donde vive el loop local de desarrollo);
// la app iOS lo consume como paquete local vía project.yml.
import PackageDescription

let package = Package(
    name: "SketchKernel",
    products: [
        .library(name: "SketchKernel", targets: ["SketchKernel"])
    ],
    targets: [
        .target(name: "SketchKernel"),
        .testTarget(name: "SketchKernelTests", dependencies: ["SketchKernel"])
    ],
    swiftLanguageVersions: [.v5]
)
