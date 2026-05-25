// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "EnglishCloze",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .executableTarget(
            name: "EnglishCloze",
            path: "Sources",
            swiftSettings: [
                .unsafeFlags(["-swift-version", "5"])
            ]
        )
    ]
)
