// swift-tools-version:5.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "TLDExtractSwift",
    products: [
        .library(
            name: "TLDExtractSwift",
            targets: ["TLDExtractSwift"])
    ],
    dependencies: [
        .package(url: "https://github.com/futamura/PunycodeSwift.git", .upToNextMajor(from: "3.0.0"))
    ],
    targets: [
        .target(
            name: "TLDExtractSwift",
            dependencies: ["Punycode"],
            path: "Sources"),
        .testTarget(
            name: "TLDExtractSwiftTests",
            dependencies: ["TLDExtractSwift"],
            path: "Tests")
    ]
)
