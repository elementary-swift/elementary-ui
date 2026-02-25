// swift-tools-version:6.2
import PackageDescription

let traceLogs = Context.environment["TRACE_LOGS"].flatMap { Bool($0) } ?? false

let package = Package(
    name: "BasicExample",
    platforms: [.macOS(.v15)],
    dependencies: [
        .package(name: "elementary-ui", path: "../../", traits: traceLogs ? ["TraceLogs"] : [])
    ],
    targets: [
        .executableTarget(
            name: "App",
            dependencies: [
                .product(name: "ElementaryUI", package: "elementary-ui")
            ]
        )
    ],
    swiftLanguageModes: [.v5]
)
