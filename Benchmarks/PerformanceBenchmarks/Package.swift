// swift-tools-version:6.2
import PackageDescription

let package = Package(
    name: "PerformanceBenchmarks",
    platforms: [.macOS(.v15)],
    dependencies: [
        .package(name: "elementary-ui", path: "../../")
    ],
    targets: [
        .executableTarget(
            name: "Benchmark",
            dependencies: [
                .product(name: "ElementaryUI", package: "elementary-ui")
            ]
        ),
    ],
    swiftLanguageModes: [.v5]
)
