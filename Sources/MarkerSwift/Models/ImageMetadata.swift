import Foundation

/// Metadata for a single image in the document
public struct ImageMetadata: Codable, Equatable, Sendable {
    /// Unique identifier for the image (e.g., "_image_001.png")
    public let id: String

    /// Original filename from the source document
    public let originalName: String

    /// Type of image after classification
    public let type: ImageType

    /// LaTeX conversion result (only for math formulas)
    public let convertedTo: String?

    /// Position information
    public let position: ImagePosition

    public init(
        id: String,
        originalName: String,
        type: ImageType,
        convertedTo: String? = nil,
        position: ImagePosition
    ) {
        self.id = id
        self.originalName = originalName
        self.type = type
        self.convertedTo = convertedTo
        self.position = position
    }
}

/// Type of image after classification
public enum ImageType: String, Codable, Sendable {
    case regular = "regular"
    case mathFormula = "math_formula"
}

/// Position of an image in the document
public struct ImagePosition: Codable, Equatable, Sendable {
    /// Paragraph index where the image appears
    public let paragraph: Int

    public init(paragraph: Int) {
        self.paragraph = paragraph
    }
}
