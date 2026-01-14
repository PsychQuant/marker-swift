import XCTest
@testable import MarkerSwift

final class ImageManagerTests: XCTestCase {
    // MARK: - Image Format Detection

    func testDetectPNG() {
        // PNG magic bytes: 89 50 4E 47 0D 0A 1A 0A
        let pngData = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])
        XCTAssertEqual(ImageManager.detectImageFormat(pngData), "png")
    }

    func testDetectJPEG() {
        // JPEG magic bytes: FF D8 FF
        let jpegData = Data([0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46])
        XCTAssertEqual(ImageManager.detectImageFormat(jpegData), "jpeg")
    }

    func testDetectGIF() {
        // GIF magic bytes: 47 49 46 38
        let gifData = Data([0x47, 0x49, 0x46, 0x38, 0x39, 0x61, 0x00, 0x00])
        XCTAssertEqual(ImageManager.detectImageFormat(gifData), "gif")
    }

    func testDetectWebP() {
        // WebP magic bytes: RIFF....WEBP
        let webpData = Data([0x52, 0x49, 0x46, 0x46, 0x00, 0x00, 0x00, 0x00])
        XCTAssertEqual(ImageManager.detectImageFormat(webpData), "webp")
    }

    func testDetectBMP() {
        // BMP magic bytes: 42 4D
        let bmpData = Data([0x42, 0x4D, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00])
        XCTAssertEqual(ImageManager.detectImageFormat(bmpData), "bmp")
    }

    func testDetectUnknown() {
        let unknownData = Data([0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07])
        XCTAssertEqual(ImageManager.detectImageFormat(unknownData), "bin")
    }

    func testDetectTooShort() {
        let shortData = Data([0x89, 0x50])
        XCTAssertEqual(ImageManager.detectImageFormat(shortData), "bin")
    }

    // MARK: - Image ID Generation

    func testGenerateImageId() {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        var manager = ImageManager(outputDirectory: tempDir)

        let id1 = manager.generateImageId(extension: "png")
        let id2 = manager.generateImageId(extension: "jpeg")
        let id3 = manager.generateImageId(extension: "gif")

        XCTAssertEqual(id1, "_image_001.png")
        XCTAssertEqual(id2, "_image_002.jpeg")
        XCTAssertEqual(id3, "_image_003.gif")
    }

    // MARK: - Statistics

    func testStatistics() {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        var manager = ImageManager(outputDirectory: tempDir)

        // Add some metadata
        manager.addMetadata(ImageMetadata(
            id: "_image_001.png",
            originalName: "img1.png",
            type: .regular,
            position: ImagePosition(paragraph: 0)
        ))
        manager.addMetadata(ImageMetadata(
            id: "_image_002.png",
            originalName: "img2.png",
            type: .mathFormula,
            convertedTo: "$x^2$",
            position: ImagePosition(paragraph: 1)
        ))
        manager.addMetadata(ImageMetadata(
            id: "_image_003.png",
            originalName: "img3.png",
            type: .regular,
            position: ImagePosition(paragraph: 2)
        ))

        let stats = manager.getStatistics()
        XCTAssertEqual(stats.totalImages, 3)
        XCTAssertEqual(stats.convertedToLatex, 1)
        XCTAssertEqual(stats.keptAsImages, 2)
    }
}
