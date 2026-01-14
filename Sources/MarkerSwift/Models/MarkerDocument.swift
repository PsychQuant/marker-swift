import Foundation

/// Complete metadata for a converted document
public struct MarkerDocument: Codable, Sendable {
    /// Original filename
    public let filename: String

    /// Conversion timestamp
    public let convertedAt: Date

    /// Conversion statistics
    public let statistics: ConversionStatistics

    /// Image metadata list
    public let images: [ImageMetadata]

    /// Table of contents
    public let tableOfContents: [TOCEntry]

    public init(
        filename: String,
        convertedAt: Date = Date(),
        statistics: ConversionStatistics,
        images: [ImageMetadata],
        tableOfContents: [TOCEntry]
    ) {
        self.filename = filename
        self.convertedAt = convertedAt
        self.statistics = statistics
        self.images = images
        self.tableOfContents = tableOfContents
    }

    enum CodingKeys: String, CodingKey {
        case filename
        case convertedAt = "converted_at"
        case statistics
        case images
        case tableOfContents = "table_of_contents"
    }
}

/// Statistics about the conversion process
public struct ConversionStatistics: Codable, Sendable {
    /// Total number of images in the document
    public let totalImages: Int

    /// Number of images converted to LaTeX
    public let convertedToLatex: Int

    /// Number of images kept as image files
    public let keptAsImages: Int

    public init(totalImages: Int, convertedToLatex: Int, keptAsImages: Int) {
        self.totalImages = totalImages
        self.convertedToLatex = convertedToLatex
        self.keptAsImages = keptAsImages
    }

    enum CodingKeys: String, CodingKey {
        case totalImages = "total_images"
        case convertedToLatex = "converted_to_latex"
        case keptAsImages = "kept_as_images"
    }
}

/// Table of contents entry
public struct TOCEntry: Codable, Sendable {
    /// Heading title
    public let title: String

    /// Heading level (1-6)
    public let level: Int

    /// Position in the document (paragraph index)
    public let position: Int

    public init(title: String, level: Int, position: Int) {
        self.title = title
        self.level = level
        self.position = position
    }
}
