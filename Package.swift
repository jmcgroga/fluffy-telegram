// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ARM64Learn",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "ARM64Learn",
            path: "Sources/ARM64Learn",
            resources: [
                .process("Resources")
            ]
        )
    ]
)
