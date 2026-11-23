// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "tiffy-cut",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "tiffy-cut",
            targets: ["TiffyCut"]
        )
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "TiffyCut",
            dependencies: [],
            path: "Sources/TiffyCut"
        ),
        .testTarget(
            name: "TiffyCutTests",
            dependencies: ["TiffyCut"],
            path: "Tests/TiffyCutTests"
        )
    ]
)
