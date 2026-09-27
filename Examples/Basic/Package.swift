// swift-tools-version: 6.4
import PackageDescription

let traceLogs = Context.environment["TRACE_LOGS"].flatMap { Bool($0) } ?? false

let package = Package(
    name: "BasicExample",
    platforms: [.macOS(.v15)],
    dependencies: [
        .package(name: "elementary-ui", path: "../../", traits: traceLogs ? ["TraceLogs"] : []),
        .package(url: "https://github.com/swiftwasm/JavaScriptKit", from: "0.58.0"),
    ],
    targets: [
        .executableTarget(
            name: "App",
            dependencies: [
                .product(name: "ElementaryUI", package: "elementary-ui")
            ],
            linkerSettings: [
                .unsafeFlags(
                    ["-Xlinker", "-z", "-Xlinker", "stack-size=8388608"],
                    .when(configuration: .debug)
                )
            ]
        )
    ],
    swiftLanguageModes: [.v5]
)
