// swift-tools-version: 6.2
import CompilerPluginSupport
import PackageDescription

let package = Package(
    name: "elementary-ui",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "ElementaryUI", targets: ["ElementaryUI", "Reactivity"])
    ],
    traits: [
        .trait(name: "TraceLogs", description: "Enables trace logs for the ElementaryUI internals")
    ],
    dependencies: [
        .package(url: "https://github.com/swiftwasm/JavaScriptKit", .upToNextMinor(from: "0.46.2")),
        .package(url: "https://github.com/elementary-swift/elementary", from: "0.6.3"),
        .package(url: "https://github.com/swiftlang/swift-syntax", "600.0.0"..<"603.0.0"),
    ],
    targets: [
        .target(
            name: "ElementaryUI",
            dependencies: [
                .product(name: "Elementary", package: "elementary"),
                .product(name: "JavaScriptKit", package: "JavaScriptKit"),
                .target(name: "BrowserInterop"),
                .target(name: "ElementaryUIMacros"),
                .target(name: "Reactivity"),
                .target(name: "_ElementaryMath"),
            ],
            swiftSettings: [
                .swiftLanguageMode(.v5),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("ConciseMagicFile"),
                .enableUpcomingFeature("ImplicitOpenExistentials"),
            ]
        ),
        .target(
            name: "BrowserInterop",
            dependencies: [
                .product(name: "JavaScriptKit", package: "JavaScriptKit")
            ],
            exclude: [
                "bridge-js.config.json",
                "Generated/JavaScript/BridgeJS.json",
            ],
            swiftSettings: [
                .swiftLanguageMode(.v5),
                .enableExperimentalFeature("Extern"),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("ConciseMagicFile"),
                .enableUpcomingFeature("ImplicitOpenExistentials"),
            ]
        ),
        .target(
            name: "_ElementaryMath",
            swiftSettings: [
                .enableExperimentalFeature("Extern")
            ]
        ),
        .macro(
            name: "ElementaryUIMacros",
            dependencies: [
                .product(name: "SwiftSyntax", package: "swift-syntax"),
                .product(name: "SwiftSyntaxBuilder", package: "swift-syntax"),
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
            ]
        ),
        .testTarget(
            name: "ElementaryUITests",
            dependencies: ["ElementaryUI"]
        ),
        /// --- REACTIVITY ---
        .target(
            name: "Reactivity",
            dependencies: ["ReactivityMacros"]
        ),
        .macro(
            name: "ReactivityMacros",
            dependencies: [
                .product(name: "SwiftSyntax", package: "swift-syntax"),
                .product(name: "SwiftSyntaxBuilder", package: "swift-syntax"),
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
            ]
        ),
        .testTarget(
            name: "ReactivityTests",
            dependencies: ["Reactivity"]
        ),
    ]
)
