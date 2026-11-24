// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Pliw-Collage",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "pliw-collage",
            targets: ["PliwCollage"]
        )
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "PliwCollage",
            dependencies: [],
            path: "Sources/PliwCollage"
        ),
        .testTarget(
            name: "PliwCollageTests",
            dependencies: ["PliwCollage"],
            path: "Tests/PliwCollageTests"
        )
    ]
)
