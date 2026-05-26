// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "AppForgeStudio",
    platforms: [.iOS(.v17)],
    dependencies: [
        .package(url: "https://github.com/Hi-Rez/Satin.git", from: "0.4.0")
    ],
    targets: [
        .executableTarget(
            name: "AppForgeStudio",
            dependencies: ["Satin"],
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
            dependencies: ["AppForgeStudio"]
        )
    ]
)
