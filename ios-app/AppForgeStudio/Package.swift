// swift-tools-version:6.1
import PackageDescription

let package = Package(
    name: "AppForgeStudio",
    defaultLocalization: "en",
    platforms: [.iOS(.v17)],
    dependencies: [
        // Satin — Metal/Swift 3D rendering framework
        // Hi-Rez/Satin archived as of April 2025. Tag 13.0.0 is the last stable.
        // TODO: fork to iwannatrip02-sys/Satin for long-term maintenance.
        .package(url: "https://github.com/Hi-Rez/Satin.git", from: "13.0.0"),
        // OCCTSwift — Open CASCADE Technology 8.0.0 Swift bindings (CAD kernel)
        // Provides: B-rep geometry, Boolean ops, fillet/chamfer, STEP/IGES, NURBS, assemblies
        // Pre-built xcframework for iOS arm64 (~190 MB). Requires Xcode 16.0+ and Swift 6.1+.
        // Pineado exacto (2026-07-18): v1.12.x salió con el slice arm64-iphoneos roto
        // (Undefined symbols StepTidy_* en archive de device). Ver project.yml.
        .package(url: "https://github.com/gsdali/OCCTSwift.git", exact: "1.11.3"),
    ],
    targets: [
        .executableTarget(
            name: "AppForgeStudio",
            dependencies: [
                "Satin",
                .product(name: "OCCTSwift", package: "OCCTSwift"),
            ],
            path: ".",
            exclude: ["docs/", "Build/", "Resources/Assets.xcassets/"],
            sources: [
                "Core/",
                "Features/",
                "Sources/",
                "Preview/",
                "Resources/"
            ],
            resources: []
        ),
        .testTarget(
            name: "AppForgeStudioTests",
            dependencies: [
                "AppForgeStudio"
            ]
        )
    ]
)
