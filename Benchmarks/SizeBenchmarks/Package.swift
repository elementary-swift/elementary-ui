// swift-tools-version:6.2
import PackageDescription

let package = Package(
    name: "SizeBenchmarks",
    platforms: [.macOS(.v15)],
    dependencies: [
        .package(name: "elementary-ui", path: "../../")
    ],
    targets: [
        .executableTarget(
            name: "HelloWorld",
            dependencies: [
                .product(name: "ElementaryUI", package: "elementary-ui")
            ]
        ),
        .executableTarget(
            name: "Counter",
            dependencies: [
                .product(name: "ElementaryUI", package: "elementary-ui")
            ]
        ),
        .executableTarget(
            name: "Animations",
            dependencies: [
                .product(name: "ElementaryUI", package: "elementary-ui")
            ]
        ),
        .executableTarget(
            name: "Inputs",
            dependencies: [
                .product(name: "ElementaryUI", package: "elementary-ui")
            ]
        ),
    ],
    swiftLanguageModes: [.v5]
)
