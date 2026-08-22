// swift-tools-version: 6.3
import PackageDescription

let package = Package(
    name: "PerformanceBenchmarks",
    platforms: [.macOS(.v15)],
    dependencies: [
        .package(name: "elementary-ui", path: "../../"),
        .package(url: "https://github.com/swiftwasm/JavaScriptKit", from: "0.58.0"),
    ],
    targets: [
        .executableTarget(
            name: "Benchmark",
            dependencies: [
                .product(name: "ElementaryUI", package: "elementary-ui")
            ]
        )
    ],
    swiftLanguageModes: [.v5]
)
