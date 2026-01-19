// swift-tools-version:6.2
import PackageDescription

let package = Package(
    name: "Embedded",
    platforms: [.macOS(.v15)],
    dependencies: [
        .package(name: "elementary-ui", path: "../../"),
        .package(url: "https://github.com/elementary-swift/elementary-flow", from: "0.1.0-alpha"),
    ],
    targets: [
        .executableTarget(
            name: "Swiftle",
            dependencies: [
                .product(name: "ElementaryUI", package: "elementary-ui"),
                .product(name: "ElementaryFlow", package: "elementary-flow"),
            ]
        )
    ],
    swiftLanguageModes: [.v5]
)
