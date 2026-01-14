import Foundation

/// Classification result for an image
public enum ImageClassification: Equatable, Sendable {
    /// The image is a math formula that should be converted to LaTeX
    case mathFormula

    /// The image is a regular image that should be kept as-is
    /// - Parameter altText: Alternative text describing the image
    case regularImage(altText: String)

    /// Check if this is a math formula
    public var isMathFormula: Bool {
        if case .mathFormula = self {
            return true
        }
        return false
    }

    /// Get alt text (empty for math formulas)
    public var altText: String {
        switch self {
        case .mathFormula:
            return ""
        case .regularImage(let text):
            return text
        }
    }
}
