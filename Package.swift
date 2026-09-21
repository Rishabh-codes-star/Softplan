// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Softplan",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "Softplan",
            path: "Sources/Softplan",
            resources: [.copy("Resources/AppLogo.png")]
        ),
        .testTarget(
            name: "SoftplanTests",
            dependencies: ["Softplan"],
            path: "Tests/SoftplanTests"
        ),
    ]
)
