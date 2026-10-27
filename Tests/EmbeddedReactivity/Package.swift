// swift-tools-version: 6.4
import CompilerPluginSupport
import PackageDescription

let package = Package(
    name: "ReactivitySmoke",
    dependencies: [
        .package(
            url: "https://github.com/apple/swift-collections",
            from: "1.7.1",
            traits: ["UnstableContainersPreview", "UnstableHashedContainers"]
        ),
        .package(url: "https://github.com/swiftlang/swift-syntax", "600.0.0"..<"605.0.0"),
    ],
    targets: [
        .target(name: "_UTF8Internals", swiftSettings: [.treatWarning("EmbeddedRestrictions", as: .warning)]),
        .target(
            name: "Reactivity",
            dependencies: [.product(name: "BasicContainers", package: "swift-collections"), "ReactivityMacros", "_UTF8Internals"],
            swiftSettings: [.treatWarning("EmbeddedRestrictions", as: .warning)]
        ),
        .macro(
            name: "ReactivityMacros",
            dependencies: [
                .product(name: "SwiftSyntax", package: "swift-syntax"), .product(name: "SwiftSyntaxBuilder", package: "swift-syntax"),
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
            ]
        ),
        .executableTarget(name: "Smoke", dependencies: ["Reactivity"]),
    ]
)
