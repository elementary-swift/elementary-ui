// swift-tools-version: 6.3
import PackageDescription

let package = Package(
    name: "WebComponentsIntegration",
    platforms: [.macOS(.v15)],
    dependencies: [
        .package(name: "elementary-ui", path: "../.."),
        .package(url: "https://github.com/swiftwasm/JavaScriptKit", from: "0.59.0"),
    ],
    targets: [
        .executableTarget(
            name: "App",
            dependencies: [
                .product(name: "ElementaryUI", package: "elementary-ui"),
                .product(name: "ElementaryWebComponents", package: "elementary-ui"),
                .product(name: "JavaScriptKit", package: "JavaScriptKit"),
            ]
        )
    ],
    swiftLanguageModes: [.v5]
)
