// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MarkerSwift",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "MarkerSwift", targets: ["MarkerSwift"])
    ],
    dependencies: [
        // Local dependency during development
        .package(path: "../markdown-swift")
    ],
    targets: [
        .target(
            name: "MarkerSwift",
            dependencies: [
                .product(name: "MarkdownSwift", package: "markdown-swift")
            ]
        ),
        .testTarget(
            name: "MarkerSwiftTests",
            dependencies: ["MarkerSwift"]
        )
    ]
)
