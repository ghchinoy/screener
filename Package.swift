// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Screener",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "screener",
            path: "Sources/screener",
            resources: [
                .process("Resources")
            ],
            linkerSettings: [
                .linkedFramework("AVKit")
            ]
        )
    ]
)
