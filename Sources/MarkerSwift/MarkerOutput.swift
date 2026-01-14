import Foundation

/// Manages the output directory structure for marker format
///
/// Creates and manages the following structure:
/// ```
/// output/
/// ├── document.md
/// ├── document_meta.json
/// └── images/
///     ├── _image_001.png
///     └── ...
/// ```
public struct MarkerOutput {
    /// Base output directory
    public let directory: URL

    /// Base filename (without extension)
    public let filename: String

    /// Initialize with output directory and filename
    public init(directory: URL, filename: String) {
        self.directory = directory
        self.filename = filename
    }

    /// URL for the markdown file
    public var markdownURL: URL {
        directory.appendingPathComponent("\(filename).md")
    }

    /// URL for the metadata JSON file
    public var metadataURL: URL {
        directory.appendingPathComponent("\(filename)_meta.json")
    }

    /// URL for the images directory
    public var imagesDirectory: URL {
        directory.appendingPathComponent("images")
    }

    /// Create the directory structure
    public func createDirectories() throws {
        let fm = FileManager.default

        // Create base directory
        try fm.createDirectory(at: directory, withIntermediateDirectories: true)

        // Create images directory
        try fm.createDirectory(at: imagesDirectory, withIntermediateDirectories: true)
    }

    /// Check if the output already exists
    public var exists: Bool {
        FileManager.default.fileExists(atPath: directory.path)
    }

    /// Remove existing output
    public func removeExisting() throws {
        let fm = FileManager.default
        if fm.fileExists(atPath: directory.path) {
            try fm.removeItem(at: directory)
        }
    }

    /// List all image files in the images directory
    public func listImages() throws -> [URL] {
        let fm = FileManager.default
        guard fm.fileExists(atPath: imagesDirectory.path) else {
            return []
        }
        let contents = try fm.contentsOfDirectory(
            at: imagesDirectory,
            includingPropertiesForKeys: nil
        )
        return contents.filter { url in
            let ext = url.pathExtension.lowercased()
            return ["png", "jpeg", "jpg", "gif", "webp", "bmp", "tiff"].contains(ext)
        }
    }
}
