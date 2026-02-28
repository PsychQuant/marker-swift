import XCTest
@testable import MarkerSwift
import OOXMLSwift
import WordToMDSwift

/// Tests for MarkerPipeline integration.
///
/// Validates the complete pipeline:
/// WordDocument → WordConverter (Tier 1-3) + ImageClassifier → Marker directory structure
final class MarkerPipelineTests: XCTestCase {

    private var tempDir: URL!
    private let pipeline = MarkerPipeline()

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("MarkerPipelineTests-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    // MARK: - Output Structure Tests

    func testPipeline_CreatesMarkdownFile() async throws {
        let doc = makeSimpleDocument()
        let outputDir = tempDir.appendingPathComponent("output")

        let result = try await pipeline.convert(
            document: doc,
            outputDirectory: outputDir,
            filename: "test"
        )

        XCTAssertTrue(FileManager.default.fileExists(atPath: result.markdownURL.path))
        let content = try String(contentsOf: result.markdownURL, encoding: .utf8)
        XCTAssertTrue(content.contains("Hello World"))
    }

    func testPipeline_CreatesMetadataYAML() async throws {
        let doc = makeSimpleDocument()
        let outputDir = tempDir.appendingPathComponent("output")

        let result = try await pipeline.convert(
            document: doc,
            outputDirectory: outputDir,
            filename: "test"
        )

        XCTAssertTrue(FileManager.default.fileExists(atPath: result.metadataYAMLURL.path))
        let yaml = try String(contentsOf: result.metadataYAMLURL, encoding: .utf8)
        XCTAssertTrue(yaml.contains("version:"))
    }

    func testPipeline_CreatesMetadataJSON() async throws {
        let doc = makeSimpleDocument()
        let outputDir = tempDir.appendingPathComponent("output")

        let result = try await pipeline.convert(
            document: doc,
            outputDirectory: outputDir,
            filename: "test"
        )

        XCTAssertTrue(FileManager.default.fileExists(atPath: result.metadataJSONURL.path))
        let json = try String(contentsOf: result.metadataJSONURL, encoding: .utf8)
        XCTAssertTrue(json.contains("\"filename\""))
        XCTAssertTrue(json.contains("\"test.docx\""))
    }

    func testPipeline_OutputFileNaming() async throws {
        let doc = makeSimpleDocument()
        let outputDir = tempDir.appendingPathComponent("output")

        let result = try await pipeline.convert(
            document: doc,
            outputDirectory: outputDir,
            filename: "mydoc"
        )

        XCTAssertTrue(result.markdownURL.lastPathComponent == "mydoc.md")
        XCTAssertTrue(result.metadataYAMLURL.lastPathComponent == "mydoc.meta.yaml")
        XCTAssertTrue(result.metadataJSONURL.lastPathComponent == "mydoc_meta.json")
    }

    // MARK: - Markdown Content Tests

    func testPipeline_MarkdownContainsHeadings() async throws {
        // Must round-trip through DocxWriter → DocxReader for semantic annotations
        let doc = try makeDocumentWithHeadings()

        let outputDir = tempDir.appendingPathComponent("output")
        let result = try await pipeline.convert(
            document: doc,
            outputDirectory: outputDir,
            filename: "headings"
        )

        XCTAssertTrue(result.markdown.contains("# Heading 1"))
        XCTAssertTrue(result.markdown.contains("## Heading 2"))
        XCTAssertTrue(result.markdown.contains("### Heading 3"))
    }

    func testPipeline_MarkdownContainsFormatting() async throws {
        var doc = WordDocument()
        var boldProps = RunProperties()
        boldProps.bold = true

        doc.body.children = [.paragraph(Paragraph(runs: [
            Run(text: "bold text", properties: boldProps),
            Run(text: " normal text")
        ]))]

        let outputDir = tempDir.appendingPathComponent("output")
        let result = try await pipeline.convert(
            document: doc,
            outputDirectory: outputDir,
            filename: "formatting"
        )

        XCTAssertTrue(result.markdown.contains("**bold text**"))
        XCTAssertTrue(result.markdown.contains("normal text"))
    }

    // MARK: - TOC Extraction Tests

    func testPipeline_ExtractsTOCEntries() async throws {
        // Semantic annotations (heading levels) are set by DocxReader,
        // so we must round-trip through .docx to get them
        var rawDoc = WordDocument()
        rawDoc.styles = Style.defaultStyles

        var h1Props = ParagraphProperties()
        h1Props.style = "Heading1"
        var h2Props = ParagraphProperties()
        h2Props.style = "Heading2"

        rawDoc.body.children = [
            .paragraph(Paragraph(text: "Introduction", properties: h1Props)),
            .paragraph(Paragraph(text: "Body text")),
            .paragraph(Paragraph(text: "Methods", properties: h2Props)),
        ]

        let doc = try roundTrip(rawDoc)

        let outputDir = tempDir.appendingPathComponent("output")
        let result = try await pipeline.convert(
            document: doc,
            outputDirectory: outputDir,
            filename: "toc"
        )

        XCTAssertEqual(result.tocEntries.count, 2)
        XCTAssertEqual(result.tocEntries[0].title, "Introduction")
        XCTAssertEqual(result.tocEntries[0].level, 1)
        XCTAssertEqual(result.tocEntries[1].title, "Methods")
        XCTAssertEqual(result.tocEntries[1].level, 2)
    }

    func testPipeline_EmptyDocumentHasNoTOC() async throws {
        let doc = WordDocument()
        let outputDir = tempDir.appendingPathComponent("output")

        let result = try await pipeline.convert(
            document: doc,
            outputDirectory: outputDir,
            filename: "empty"
        )

        XCTAssertEqual(result.tocEntries.count, 0)
        XCTAssertEqual(result.imageCount, 0)
    }

    // MARK: - Metadata JSON Content Tests

    func testPipeline_MetadataJSONHasCorrectStatistics() async throws {
        let doc = makeSimpleDocument()
        let outputDir = tempDir.appendingPathComponent("output")

        let result = try await pipeline.convert(
            document: doc,
            outputDirectory: outputDir,
            filename: "stats"
        )

        let jsonData = try Data(contentsOf: result.metadataJSONURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let markerDoc = try decoder.decode(MarkerDocument.self, from: jsonData)

        XCTAssertEqual(markerDoc.filename, "stats.docx")
        XCTAssertEqual(markerDoc.statistics.totalImages, 0)
        XCTAssertEqual(markerDoc.statistics.convertedToLatex, 0)
        XCTAssertEqual(markerDoc.statistics.keptAsImages, 0)
    }

    func testPipeline_MetadataJSONHasTOC() async throws {
        var rawDoc = WordDocument()
        rawDoc.styles = Style.defaultStyles

        var h1Props = ParagraphProperties()
        h1Props.style = "Heading1"
        rawDoc.body.children = [
            .paragraph(Paragraph(text: "Chapter One", properties: h1Props))
        ]

        let doc = try roundTrip(rawDoc)

        let outputDir = tempDir.appendingPathComponent("output")
        let result = try await pipeline.convert(
            document: doc,
            outputDirectory: outputDir,
            filename: "toc-json"
        )

        let jsonData = try Data(contentsOf: result.metadataJSONURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let markerDoc = try decoder.decode(MarkerDocument.self, from: jsonData)

        XCTAssertEqual(markerDoc.tableOfContents.count, 1)
        XCTAssertEqual(markerDoc.tableOfContents[0].title, "Chapter One")
        XCTAssertEqual(markerDoc.tableOfContents[0].level, 1)
    }

    // MARK: - File-based API Test

    func testPipeline_FileBasedAPI() async throws {
        // Create a .docx file first
        var doc = WordDocument()
        doc.body.children = [.paragraph(Paragraph(text: "File-based test"))]
        let docxURL = tempDir.appendingPathComponent("input.docx")
        try DocxWriter.write(doc, to: docxURL)

        let outputDir = tempDir.appendingPathComponent("output")
        let result = try await pipeline.convert(
            docxURL: docxURL,
            outputDirectory: outputDir,
            filename: "input"
        )

        XCTAssertTrue(result.markdown.contains("File-based test"))
        XCTAssertTrue(FileManager.default.fileExists(atPath: result.markdownURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: result.metadataYAMLURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: result.metadataJSONURL.path))
    }

    // MARK: - Helpers

    private func makeSimpleDocument() -> WordDocument {
        var doc = WordDocument()
        doc.body.children = [.paragraph(Paragraph(text: "Hello World"))]
        return doc
    }

    /// Write→Read round-trip to get DocxReader semantic annotations
    private func roundTrip(_ doc: WordDocument) throws -> WordDocument {
        let url = tempDir.appendingPathComponent("rt-\(UUID().uuidString).docx")
        try DocxWriter.write(doc, to: url)
        return try DocxReader.read(from: url)
    }

    /// Create a document with heading styles via round-trip
    private func makeDocumentWithHeadings() throws -> WordDocument {
        var doc = WordDocument()
        doc.styles = Style.defaultStyles

        for level in 1...3 {
            var props = ParagraphProperties()
            props.style = "Heading\(level)"
            doc.body.children.append(.paragraph(Paragraph(text: "Heading \(level)", properties: props)))
        }

        return try roundTrip(doc)
    }
}
