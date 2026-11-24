// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Tiffy-Collage",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "tiffy-collage",
            targets: ["TiffyCollage"]
        )
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "TiffyCollage",
            dependencies: [],
            path: "Sources/TiffyCollage"
        ),
        .testTarget(
            name: "TiffyCollageTests",
            dependencies: ["TiffyCollage"],
            path: "Tests/TiffyCollageTests"
        )
    ]
)
