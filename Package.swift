// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "M913",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "M913", path: "Sources/M913")
    ]
)
