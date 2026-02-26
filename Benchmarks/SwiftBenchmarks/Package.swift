// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "SwiftBenchmarks",
    platforms: [.macOS(.v15)],
    dependencies: [
        .package(url: "https://github.com/ordo-one/package-benchmark", from: "1.29.0"),
        .package(path: "../.."),
    ],
    targets: [
        .executableTarget(
            name: "SwiftBenchmarks",
            dependencies: [
                .product(name: "Benchmark", package: "package-benchmark"),
                .product(name: "ElementaryUI", package: "elementary-ui"),
            ],
            path: "Benchmarks/SwiftBenchmarks",
            plugins: [
                .plugin(name: "BenchmarkPlugin", package: "package-benchmark"),
            ]
        ),
    ]
)
