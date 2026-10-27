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
        .executableTarget(name: "Examples", dependencies: ["ObjcValue"]),
    ]
)
