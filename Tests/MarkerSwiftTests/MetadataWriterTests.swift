import XCTest
@testable import MarkerSwift

final class MetadataWriterTests: XCTestCase {
    func testEncodeDocument() throws {
        let document = MarkerDocument(
            filename: "test.docx",
            statistics: ConversionStatistics(
                totalImages: 3,
                convertedToLatex: 1,
                keptAsImages: 2
            ),
            images: [
                ImageMetadata(
                    id: "_image_001.png",
                    originalName: "image1.png",
                    type: .regular,
                    position: ImagePosition(paragraph: 0)
                )
            ],
            tableOfContents: [
                TOCEntry(title: "Title", level: 1, position: 0)
            ]
        )

        let writer = MetadataWriter()
        let jsonString = try writer.encodeToString(document)

        // Verify JSON structure
        XCTAssertTrue(jsonString.contains("\"filename\""))
        XCTAssertTrue(jsonString.contains("\"test.docx\""))
        XCTAssertTrue(jsonString.contains("\"total_images\""))
        XCTAssertTrue(jsonString.contains("\"converted_to_latex\""))
        XCTAssertTrue(jsonString.contains("\"kept_as_images\""))
        XCTAssertTrue(jsonString.contains("\"table_of_contents\""))
    }

    func testSnakeCaseKeys() throws {
        let document = MarkerDocument(
            filename: "test.docx",
            statistics: ConversionStatistics(
                totalImages: 0,
                convertedToLatex: 0,
                keptAsImages: 0
            ),
            images: [],
            tableOfContents: []
        )

        let writer = MetadataWriter()
        let jsonString = try writer.encodeToString(document)

        // Verify snake_case keys
        XCTAssertTrue(jsonString.contains("\"converted_at\""))
        XCTAssertTrue(jsonString.contains("\"total_images\""))
        XCTAssertTrue(jsonString.contains("\"converted_to_latex\""))
        XCTAssertTrue(jsonString.contains("\"kept_as_images\""))
        XCTAssertTrue(jsonString.contains("\"table_of_contents\""))
    }
}
