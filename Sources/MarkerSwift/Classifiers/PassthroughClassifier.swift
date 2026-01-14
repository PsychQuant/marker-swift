import Foundation

/// Default classifier that keeps all images as-is without any processing
///
/// Use this classifier when you don't have OCR/formula detection available,
/// or when you want to preserve all images in their original form.
///
/// ## Usage
///
/// ```swift
/// let classifier = PassthroughClassifier()
/// let writer = MarkerWriter(classifier: classifier)
/// ```
public struct PassthroughClassifier: ImageClassifier {
    /// Default alt text for images when none is provided
    public let defaultAltText: String

    /// Initialize with optional default alt text
    /// - Parameter defaultAltText: Alt text to use for all images (default: "Image")
    public init(defaultAltText: String = "Image") {
        self.defaultAltText = defaultAltText
    }

    /// Always classifies images as regular images
    /// - Parameter image: The image data (ignored)
    /// - Returns: `.regularImage` with the default alt text
    public func classify(_ image: Data) async throws -> ImageClassification {
        return .regularImage(altText: defaultAltText)
    }

    /// Not supported - this classifier doesn't convert to LaTeX
    /// - Parameter image: The image data
    /// - Throws: `ImageClassifierError.latexConversionFailed`
    public func convertToLatex(_ image: Data) async throws -> String {
        throw ImageClassifierError.latexConversionFailed(
            "PassthroughClassifier does not support LaTeX conversion"
        )
    }
}
