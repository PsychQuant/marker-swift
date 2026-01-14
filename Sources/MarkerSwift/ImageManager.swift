import Foundation

/// Manages image files for marker output
public struct ImageManager {
    /// Base directory for images
    public let imagesDirectory: URL

    /// Counter for generating unique image IDs
    private var imageCounter: Int = 0

    /// Collected image metadata
    private var imageMetadata: [ImageMetadata] = []

    /// Initialize with output directory
    /// - Parameter outputDirectory: The base output directory (images will be in outputDirectory/images/)
    public init(outputDirectory: URL) {
        self.imagesDirectory = outputDirectory.appendingPathComponent("images")
    }

    /// Create the images directory if it doesn't exist
    public func createDirectory() throws {
        try FileManager.default.createDirectory(
            at: imagesDirectory,
            withIntermediateDirectories: true
        )
    }

    /// Generate a unique image ID
    /// - Parameter extension: File extension (e.g., "png", "jpeg")
    /// - Returns: Unique image ID like "_image_001.png"
    public mutating func generateImageId(extension ext: String) -> String {
        imageCounter += 1
        let paddedNumber = String(format: "%03d", imageCounter)
        return "_image_\(paddedNumber).\(ext)"
    }

    /// Save an image to the images directory
    /// - Parameters:
    ///   - data: Image data
    ///   - id: Image ID (from generateImageId)
    /// - Returns: Relative path to the image (for use in markdown)
    public func saveImage(_ data: Data, id: String) throws -> String {
        let fileURL = imagesDirectory.appendingPathComponent(id)
        try data.write(to: fileURL)
        return "images/\(id)"
    }

    /// Add image metadata for tracking
    public mutating func addMetadata(_ metadata: ImageMetadata) {
        imageMetadata.append(metadata)
    }

    /// Get all collected image metadata
    public func getMetadata() -> [ImageMetadata] {
        return imageMetadata
    }

    /// Get conversion statistics
    public func getStatistics() -> ConversionStatistics {
        let total = imageMetadata.count
        let converted = imageMetadata.filter { $0.type == .mathFormula }.count
        let kept = total - converted
        return ConversionStatistics(
            totalImages: total,
            convertedToLatex: converted,
            keptAsImages: kept
        )
    }

    /// Detect image format from data
    /// - Parameter data: Image data
    /// - Returns: File extension ("png", "jpeg", "gif", etc.)
    public static func detectImageFormat(_ data: Data) -> String {
        guard data.count >= 8 else { return "bin" }

        let bytes = [UInt8](data.prefix(8))

        // PNG: 89 50 4E 47 0D 0A 1A 0A
        if bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E && bytes[3] == 0x47 {
            return "png"
        }

        // JPEG: FF D8 FF
        if bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF {
            return "jpeg"
        }

        // GIF: 47 49 46 38
        if bytes[0] == 0x47 && bytes[1] == 0x49 && bytes[2] == 0x46 && bytes[3] == 0x38 {
            return "gif"
        }

        // WebP: RIFF....WEBP
        if bytes[0] == 0x52 && bytes[1] == 0x49 && bytes[2] == 0x46 && bytes[3] == 0x46 {
            return "webp"
        }

        // BMP: 42 4D
        if bytes[0] == 0x42 && bytes[1] == 0x4D {
            return "bmp"
        }

        // TIFF: 49 49 or 4D 4D
        if (bytes[0] == 0x49 && bytes[1] == 0x49) || (bytes[0] == 0x4D && bytes[1] == 0x4D) {
            return "tiff"
        }

        return "bin"
    }
}
