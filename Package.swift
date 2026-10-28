// swift-tools-version: 5.9
import PackageDescription
import CompilerPluginSupport

let package = Package(
    name: "ObjcValue",
    platforms: [
        .macOS(.v10_15),
        .iOS(.v13),
        .tvOS(.v13),
        .watchOS(.v6)
    ],
    products: [
        .library(
            name: "ObjcValue",
            targets: ["ObjcValue"]
        ),
        .executable(
            name: "Examples",
            targets: ["Examples"]
        ),
        .executable(
            name: "ObjCExamples",
            targets: ["ObjCExamples"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-syntax.git", from: "510.0.0")
    ],
    targets: [
        .macro(
            name: "ValueMacros",
            dependencies: [
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax")
            ]
        ),
        .target(
            name: "ObjcValue",
            dependencies: ["ValueMacros"]
        ),
        .target(name: "ExampleModels", dependencies: ["ObjcValue"]),
        .executableTarget(name: "Examples", dependencies: ["ExampleModels"]),
        .executableTarget(name: "ObjCExamples", dependencies: ["ExampleModels"]),
        .testTarget(
            name: "ObjcValueTests",
            dependencies: [
                "ValueMacros",
                .product(name: "SwiftSyntaxMacrosTestSupport", package: "swift-syntax"),
            ]
        ),
        .testTarget(name: "ObjcValueRuntimeTests", dependencies: ["ObjcValue"]),
        .testTarget(name: "ObjCInteropTests", dependencies: ["ExampleModels"]),
    ]
)
