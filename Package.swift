// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Gapfill",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .executableTarget(
            name: "Gapfill",
            path: "Sources",
            swiftSettings: [
                .unsafeFlags(["-swift-version", "5"])
            ]
        ),
        .testTarget(
            name: "GapfillTests",
            dependencies: ["Gapfill"]
        )
    ]
)
