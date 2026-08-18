// swift-tools-version:5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "TLDExtractSwift",
    platforms: [
        .macOS(.v10_13),
        .iOS(.v12),
        .tvOS(.v12),
        .watchOS(.v4),
        .visionOS(.v1),
    ],
    products: [
        .library(
            name: "TLDExtractSwift",
            targets: ["TLDExtractSwift"])
    ],
    dependencies: [
        .package(url: "https://github.com/futamura/PunycodeSwift.git", .upToNextMajor(from: "4.0.0"))
    ],
    targets: [
        .target(
            name: "TLDExtractSwift",
            dependencies: [.product(name: "Punycode", package: "PunycodeSwift")],
            path: "Sources",
            exclude: ["TLDExtractSwift.h"]),
        .testTarget(
            name: "TLDExtractSwiftTests",
            dependencies: ["TLDExtractSwift"],
            path: "Tests"),
    ]
)
