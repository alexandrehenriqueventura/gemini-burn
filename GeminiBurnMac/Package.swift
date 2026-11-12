// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "gemini-burn",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "gemini-burn", targets: ["GeminiBurnMac"])
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "GeminiBurnMac",
            path: "Sources/GeminiBurnMac",
            resources: [
                .copy("Resources")
            ]
        )
    ]
)