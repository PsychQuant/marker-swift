// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MarkerSwift",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "MarkerSwift", targets: ["MarkerSwift"])
    ],
    dependencies: [
        .package(url: "https://github.com/kiki830621/markdown-swift.git", from: "0.1.0")
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
