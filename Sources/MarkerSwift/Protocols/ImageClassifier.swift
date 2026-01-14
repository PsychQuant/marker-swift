import Foundation

/// Protocol for image classification and LaTeX conversion
///
/// Implement this protocol to provide custom image classification logic.
/// The default implementation (`PassthroughClassifier`) keeps all images as-is.
///
/// ## Example Implementation
///
/// ```swift
/// struct SuryaClassifier: ImageClassifier {
///     func classify(_ image: Data) async throws -> ImageClassification {
///         // Use local Surya model to detect if image is a math formula
///         let isMath = await suryaModel.detectMath(image)
///         if isMath {
///             return .mathFormula
///         }
///         let description = await suryaModel.describe(image)
///         return .regularImage(altText: description)
///     }
///
///     func convertToLatex(_ image: Data) async throws -> String {
///         // Use local Texify model to convert
///         return await texifyModel.convert(image)
///     }
/// }
/// ```
public protocol ImageClassifier: Sendable {
    /// Classify an image as either a math formula or regular image
    /// - Parameter image: The image data to classify
    /// - Returns: Classification result
    func classify(_ image: Data) async throws -> ImageClassification

    /// Convert a math formula image to LaTeX
    /// - Parameter image: The image data containing a math formula
    /// - Returns: LaTeX string representation of the formula
    /// - Note: Only call this for images classified as `.mathFormula`
    func convertToLatex(_ image: Data) async throws -> String
}

/// Errors that can occur during image classification
public enum ImageClassifierError: Error, LocalizedError {
    case classificationFailed(String)
    case latexConversionFailed(String)
    case unsupportedImageFormat

    public var errorDescription: String? {
        switch self {
        case .classificationFailed(let message):
            return "Image classification failed: \(message)"
        case .latexConversionFailed(let message):
            return "LaTeX conversion failed: \(message)"
        case .unsupportedImageFormat:
            return "Unsupported image format"
        }
    }
}
