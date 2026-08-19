// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MarkerSwift",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "MarkerSwift", targets: ["MarkerSwift"])
    ],
    dependencies: [
        .package(url: "https://github.com/PsychQuant/markdown-swift.git", from: "0.1.0"),
        .package(url: "https://github.com/PsychQuant/word-to-md-swift.git", from: "1.0.0"),
        .package(url: "https://github.com/PsychQuant/ooxml-swift.git", "2.0.0"..<"4.0.0"),
    ],
    targets: [
        .target(
            name: "MarkerSwift",
            dependencies: [
                .product(name: "MarkdownSwift", package: "markdown-swift"),
                .product(name: "WordToMD", package: "word-to-md-swift"),
                .product(name: "OOXMLSwift", package: "ooxml-swift"),
            ]
        ),
        .testTarget(
            name: "MarkerSwiftTests",
            dependencies: [
                "MarkerSwift",
                .product(name: "OOXMLSwift", package: "ooxml-swift"),
            ]
        )
    ]
)
