// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "HangulSync",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "HangulSync",
            path: "Sources/HangulSync"
        )
    ]
)
