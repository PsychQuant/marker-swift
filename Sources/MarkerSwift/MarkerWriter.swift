import Foundation
import MarkdownSwift

/// Main API for writing marker-format output (MD + JSON + images)
///
/// MarkerWriter combines markdown generation, image management, and metadata
/// to produce marker-style output with proper directory structure.
///
/// ## Usage
///
/// ```swift
/// let writer = try MarkerWriter(
///     outputDirectory: URL(fileURLWithPath: "output/"),
///     filename: "document",
///     classifier: PassthroughClassifier()
/// )
///
/// // Write content
/// try writer.heading("Title", level: 1)
/// try writer.paragraph("Some text")
/// try await writer.image(data: imageData, originalName: "img1.png", paragraph: 2)
///
/// // Finalize and write metadata
/// try writer.finalize()
/// ```
public class MarkerWriter {
    // MARK: - Properties

    /// Output directory
    public let outputDirectory: URL

    /// Base filename (without extension)
    public let filename: String

    /// Image classifier for determining image handling
    public let classifier: any ImageClassifier

    /// Internal markdown content buffer
    private var markdownContent: String = ""

    /// Image manager for file operations
    private var imageManager: ImageManager

    /// Table of contents entries
    private var tocEntries: [TOCEntry] = []

    /// Current paragraph index
    private var paragraphIndex: Int = 0

    /// Markdown writer for formatting
    private var mdOutput: StringOutput
    private var mdWriter: MarkdownWriter<StringOutput>

    // MARK: - Initialization

    /// Initialize a new MarkerWriter
    /// - Parameters:
    ///   - outputDirectory: Directory to write output files
    ///   - filename: Base filename for output (without extension)
    ///   - classifier: Image classifier to use
    public init(
        outputDirectory: URL,
        filename: String,
        classifier: any ImageClassifier = PassthroughClassifier()
    ) throws {
        self.outputDirectory = outputDirectory
        self.filename = filename
        self.classifier = classifier
        self.imageManager = ImageManager(outputDirectory: outputDirectory)
        self.mdOutput = StringOutput()
        self.mdWriter = MarkdownWriter(output: mdOutput)

        // Create output directory structure
        try FileManager.default.createDirectory(
            at: outputDirectory,
            withIntermediateDirectories: true
        )
        try imageManager.createDirectory()
    }

    // MARK: - Block Elements

    /// Write a heading
    public func heading(_ text: String, level: Int) throws {
        try mdWriter.heading(text, level: level)
        tocEntries.append(TOCEntry(title: text, level: level, position: paragraphIndex))
        paragraphIndex += 1
    }

    /// Write a paragraph
    public func paragraph(_ text: String) throws {
        try mdWriter.paragraph(text)
        paragraphIndex += 1
    }

    /// Write a bullet list item
    public func bulletItem(_ text: String, level: Int = 0) throws {
        try mdWriter.bulletItem(text, level: level)
    }

    /// Write a numbered list item
    public func numberedItem(_ text: String, level: Int = 0) throws {
        try mdWriter.numberedItem(text, level: level)
    }

    /// End current list
    public func endList() throws {
        try mdWriter.endList()
        paragraphIndex += 1
    }

    /// Write a table
    public func table(headers: [String], rows: [[String]], alignment: [TableAlignment]? = nil) throws {
        try mdWriter.table(headers: headers, rows: rows, alignment: alignment)
        paragraphIndex += 1
    }

    /// Write a code block
    public func codeBlock(_ code: String, language: String? = nil) throws {
        try mdWriter.codeBlock(code, language: language)
        paragraphIndex += 1
    }

    /// Write a blockquote
    public func blockquote(_ text: String) throws {
        try mdWriter.blockquote(text)
        paragraphIndex += 1
    }

    /// Write a horizontal rule
    public func horizontalRule() throws {
        try mdWriter.horizontalRule()
        paragraphIndex += 1
    }

    /// Write raw content (no escaping)
    public func raw(_ text: String) throws {
        try mdWriter.raw(text)
    }

    // MARK: - Image Handling

    /// Process and write an image
    /// - Parameters:
    ///   - data: Image binary data
    ///   - originalName: Original filename from source document
    /// - Returns: What was written (either LaTeX or image reference)
    @discardableResult
    public func image(data: Data, originalName: String) async throws -> ImageResult {
        let classification = try await classifier.classify(data)

        switch classification {
        case .mathFormula:
            // Convert to LaTeX and embed inline
            let latex = try await classifier.convertToLatex(data)
            let latexInline = "$\(latex)$"
            try mdWriter.raw(latexInline)
            try mdWriter.raw("\n\n")

            // Track metadata
            let ext = ImageManager.detectImageFormat(data)
            let id = imageManager.generateImageId(extension: ext)
            let metadata = ImageMetadata(
                id: id,
                originalName: originalName,
                type: .mathFormula,
                convertedTo: latexInline,
                position: ImagePosition(paragraph: paragraphIndex)
            )
            imageManager.addMetadata(metadata)
            paragraphIndex += 1

            return .latex(latexInline)

        case .regularImage(let altText):
            // Save image file and write reference
            let ext = ImageManager.detectImageFormat(data)
            let id = imageManager.generateImageId(extension: ext)
            let relativePath = try imageManager.saveImage(data, id: id)

            // Write markdown image reference
            let imageRef = MarkdownInline.image(altText, url: relativePath)
            try mdWriter.paragraph(imageRef)

            // Track metadata
            let metadata = ImageMetadata(
                id: id,
                originalName: originalName,
                type: .regular,
                position: ImagePosition(paragraph: paragraphIndex)
            )
            imageManager.addMetadata(metadata)
            paragraphIndex += 1

            return .imageFile(path: relativePath, id: id)
        }
    }

    // MARK: - Finalization

    /// Finalize output and write all files
    /// - Returns: URLs of written files
    @discardableResult
    public func finalize() throws -> MarkerOutputFiles {
        // Get markdown content
        let content = mdWriter.getOutput().content

        // Write markdown file
        let mdURL = outputDirectory.appendingPathComponent("\(filename).md")
        try content.write(to: mdURL, atomically: true, encoding: .utf8)

        // Create and write metadata
        let document = MarkerDocument(
            filename: "\(filename).docx",
            statistics: imageManager.getStatistics(),
            images: imageManager.getMetadata(),
            tableOfContents: tocEntries
        )

        let metaURL = outputDirectory.appendingPathComponent("\(filename)_meta.json")
        let metadataWriter = MetadataWriter()
        try metadataWriter.write(document, to: metaURL)

        return MarkerOutputFiles(
            markdownURL: mdURL,
            metadataURL: metaURL,
            imagesDirectory: imageManager.imagesDirectory
        )
    }

    /// Get current markdown content (before finalization)
    public func getCurrentContent() -> String {
        return mdWriter.getOutput().content
    }
}

// MARK: - Supporting Types

/// Result of processing an image
public enum ImageResult {
    case latex(String)
    case imageFile(path: String, id: String)
}

/// URLs of output files
public struct MarkerOutputFiles {
    public let markdownURL: URL
    public let metadataURL: URL
    public let imagesDirectory: URL
}
