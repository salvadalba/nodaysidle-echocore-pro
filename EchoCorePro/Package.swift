// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "EchoCorePro",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "EchoCorePro",
            targets: ["EchoCorePro"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/argmaxinc/WhisperKit.git", from: "0.9.0"),
    ],
    targets: [
        .executableTarget(
            name: "EchoCorePro",
            dependencies: ["WhisperKit"],
            path: "EchoCorePro"
        ),
    ]
)
