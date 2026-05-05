// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "AppForgeStudio",
    platforms: [.iOS(.v17)],
    dependencies: [
        .package(url: "https://github.com/s1ddok/Satin.git", from: "0.3.0")
    ],
    targets: [
        .executableTarget(
            name: "AppForgeStudio",
            dependencies: ["Satin"],
            path: ".",
            exclude: ["docs/", "Resources/", "Models/Model.swift", "Models/CADHistory.swift"],
            resources: []
        )
    ]
)
