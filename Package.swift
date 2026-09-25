// swift-tools-version: 6.4
import CompilerPluginSupport
import PackageDescription

let package = Package(
    name: "elementary-ui",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "ElementaryUI", targets: ["ElementaryUI", "Reactivity"]),
        .library(name: "ElementaryWebComponents", targets: ["ElementaryWebComponents"]),
    ],
    traits: [
        .trait(name: "TraceLogs", description: "Enables trace logs for the ElementaryUI internals")
    ],
    dependencies: [
        .package(url: "https://github.com/swiftwasm/JavaScriptKit", .upToNextMinor(from: "0.58.0")),
        .package(url: "https://github.com/elementary-swift/elementary", from: "0.8.2"),
        .package(
            url: "https://github.com/apple/swift-collections",
            .upToNextMinor(from: "1.6.0"),
            traits: ["UnstableContainersPreview", "UnstableHashedContainers"]
        ),
        .package(url: "https://github.com/swiftlang/swift-syntax", "600.0.0"..<"605.0.0"),
    ],
    targets: [
        .target(name: "_UTF8Internals"),
        .target(
            name: "ElementaryUI",
            dependencies: [
                .product(name: "Elementary", package: "elementary"),
                .product(name: "JavaScriptKit", package: "JavaScriptKit"),
                .product(name: "BasicContainers", package: "swift-collections"),
                .product(name: "ContainersPreview", package: "swift-collections"),
                .target(name: "BrowserInterop"),
                .target(name: "ElementaryUIMacros"),
                .target(name: "_UTF8Internals"),
                .target(name: "Reactivity"),
                .target(name: "_ElementaryMath"),
            ],
            swiftSettings: [
                .swiftLanguageMode(.v5),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("ConciseMagicFile"),
                .enableUpcomingFeature("ImplicitOpenExistentials"),
                .enableExperimentalFeature("Lifetimes"),
                .enableExperimentalFeature("SuppressedAssociatedTypesWithDefaults"),
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
            name: "ElementaryWebComponents",
            dependencies: [
                .target(name: "ElementaryUI"),
                .target(name: "ElementaryUIMacros"),
                .target(name: "Reactivity"),
                .product(name: "BasicContainers", package: "swift-collections"),
                .product(name: "JavaScriptKit", package: "JavaScriptKit"),
            ],
            exclude: [
                "bridge-js.config.json",
                "Generated/JavaScript/BridgeJS.json",
                "JavaScript",
            ],
            swiftSettings: [
                .swiftLanguageMode(.v5),
                .enableExperimentalFeature("Extern"),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("ConciseMagicFile"),
                .enableUpcomingFeature("ImplicitOpenExistentials"),
                .enableExperimentalFeature("Lifetimes"),
                .enableExperimentalFeature("SuppressedAssociatedTypesWithDefaults"),
            ]
        ),
        .target(
            name: "_ElementaryMath",
            dependencies: ["BrowserInterop"],
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
        .testTarget(
            name: "ElementaryWebComponentsTests",
            dependencies: ["ElementaryUI", "ElementaryWebComponents", "Reactivity"]
        ),
        .testTarget(
            name: "ElementaryUIMacrosTests",
            dependencies: [
                "ElementaryUIMacros",
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftSyntaxMacrosTestSupport", package: "swift-syntax"),
            ]
        ),
        /// --- REACTIVITY ---
        .target(
            name: "Reactivity",
            dependencies: [
                .product(name: "BasicContainers", package: "swift-collections"),
                "ReactivityMacros",
                "_UTF8Internals",
            ]
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
            dependencies: ["Reactivity", "_UTF8Internals"]
        ),
    ]
)
