import Foundation
import OOXMLSwift
import WordToMDSwift
import CommonConverterSwift

/// High-level pipeline that converts .docx → Marker directory structure.
///
/// Combines:
/// 1. WordConverter (Tier 1 MD)
/// 2. FigureExtractor (Tier 2 images) — via ConversionOptions
/// 3. MetadataCollector (Tier 3 YAML sidecar) — via ConversionOptions
/// 4. ImageClassifier (marker-swift's image classification)
/// 5. Marker metadata JSON (image index + classification)
///
/// Output structure:
/// ```
/// output/
/// ├── document.md                  ← Tier 1 canonical markdown
/// ├── document.meta.yaml           ← Tier 3 lossless sidecar
/// ├── document_meta.json           ← Marker image index
/// ├── figures/                     ← Tier 2 extracted images (from WordConverter)
/// │   ├── image1.png
/// │   └── ...
/// └── images/                      ← Marker classified images
///     ├── _image_001.png
///     └── ...
/// ```
public struct MarkerPipeline {

    /// Image classifier for determining image handling
    public let classifier: any ImageClassifier

    public init(classifier: any ImageClassifier = PassthroughClassifier()) {
        self.classifier = classifier
    }

    // MARK: - File-based API

    /// Convert a .docx file to Marker directory structure.
    ///
    /// - Parameters:
    ///   - docxURL: Path to the .docx file
    ///   - outputDirectory: Directory to write output files
    ///   - filename: Base filename (without extension)
    /// - Returns: Pipeline result with file URLs
    public func convert(
        docxURL: URL,
        outputDirectory: URL,
        filename: String
    ) async throws -> MarkerPipelineResult {
        let document = try DocxReader.read(from: docxURL)
        return try await convert(
            document: document,
            outputDirectory: outputDirectory,
            filename: filename
        )
    }

    // MARK: - In-Memory API

    /// Convert a WordDocument to Marker directory structure.
    ///
    /// - Parameters:
    ///   - document: The WordDocument to convert
    ///   - outputDirectory: Directory to write output files
    ///   - filename: Base filename (without extension)
    /// - Returns: Pipeline result with file URLs
    public func convert(
        document: WordDocument,
        outputDirectory: URL,
        filename: String
    ) async throws -> MarkerPipelineResult {
        let fm = FileManager.default

        // Create output directory structure
        try fm.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

        let figuresDir = outputDirectory.appendingPathComponent("figures")
        let metaYAMLURL = outputDirectory.appendingPathComponent("\(filename).meta.yaml")
        let mdURL = outputDirectory.appendingPathComponent("\(filename).md")

        // Step 1-3: Use WordConverter with Tier 3 fidelity
        // This automatically handles: MD output, figure extraction, metadata YAML
        let converter = WordConverter()
        let options = ConversionOptions(
            fidelity: .marker,
            useHTMLExtensions: true,
            figuresDirectory: figuresDir,
            metadataOutput: metaYAMLURL
        )

        let markdown = try converter.convertToString(document: document, options: options)

        // Write markdown file
        try markdown.write(to: mdURL, atomically: true, encoding: .utf8)

        // Step 4: Image classification (marker-swift's own logic)
        var classifiedImages: [ImageMetadata] = []
        for image in document.images {
            let classification = try await classifier.classify(image.data)
            let ext = ImageManager.detectImageFormat(image.data)
            let id = "\(image.id).\(ext)"

            let metadata = ImageMetadata(
                id: id,
                originalName: image.fileName,
                type: classification == .mathFormula ? .mathFormula : .regular,
                position: ImagePosition(paragraph: 0)
            )
            classifiedImages.append(metadata)
        }

        // Step 5: Write Marker metadata JSON
        let tocEntries = extractTOC(from: document)
        let stats = ConversionStatistics(
            totalImages: document.images.count,
            convertedToLatex: classifiedImages.filter { $0.type == .mathFormula }.count,
            keptAsImages: classifiedImages.filter { $0.type == .regular }.count
        )

        let markerDoc = MarkerDocument(
            filename: "\(filename).docx",
            statistics: stats,
            images: classifiedImages,
            tableOfContents: tocEntries
        )

        let metaJSONURL = outputDirectory.appendingPathComponent("\(filename)_meta.json")
        let metadataWriter = MetadataWriter()
        try metadataWriter.write(markerDoc, to: metaJSONURL)

        return MarkerPipelineResult(
            markdownURL: mdURL,
            metadataYAMLURL: metaYAMLURL,
            metadataJSONURL: metaJSONURL,
            figuresDirectory: figuresDir,
            markdown: markdown,
            imageCount: document.images.count,
            tocEntries: tocEntries
        )
    }

    // MARK: - Helpers

    /// Extract table of contents from a WordDocument
    private func extractTOC(from document: WordDocument) -> [TOCEntry] {
        var entries: [TOCEntry] = []
        for (index, child) in document.body.children.enumerated() {
            if case .paragraph(let para) = child,
               let semantic = para.semantic,
               case .heading(let level) = semantic.type {
                let text = para.getText()
                if !text.isEmpty {
                    entries.append(TOCEntry(title: text, level: level, position: index))
                }
            }
        }
        return entries
    }
}

// MARK: - Pipeline Result

/// Result of the MarkerPipeline conversion
public struct MarkerPipelineResult {
    /// URL of the generated markdown file
    public let markdownURL: URL

    /// URL of the Tier 3 metadata YAML sidecar
    public let metadataYAMLURL: URL

    /// URL of the Marker metadata JSON
    public let metadataJSONURL: URL

    /// URL of the figures directory
    public let figuresDirectory: URL

    /// The markdown content
    public let markdown: String

    /// Number of images in the document
    public let imageCount: Int

    /// Table of contents entries
    public let tocEntries: [TOCEntry]
}
