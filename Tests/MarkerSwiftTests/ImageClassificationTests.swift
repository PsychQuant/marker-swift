import XCTest
@testable import MarkerSwift

final class ImageClassificationTests: XCTestCase {
    // MARK: - ImageClassification Tests

    func testMathFormulaClassification() {
        let classification = ImageClassification.mathFormula
        XCTAssertTrue(classification.isMathFormula)
        XCTAssertEqual(classification.altText, "")
    }

    func testRegularImageClassification() {
        let classification = ImageClassification.regularImage(altText: "A photo")
        XCTAssertFalse(classification.isMathFormula)
        XCTAssertEqual(classification.altText, "A photo")
    }

    func testClassificationEquality() {
        XCTAssertEqual(
            ImageClassification.mathFormula,
            ImageClassification.mathFormula
        )
        XCTAssertEqual(
            ImageClassification.regularImage(altText: "test"),
            ImageClassification.regularImage(altText: "test")
        )
        XCTAssertNotEqual(
            ImageClassification.regularImage(altText: "a"),
            ImageClassification.regularImage(altText: "b")
        )
    }

    // MARK: - PassthroughClassifier Tests

    func testPassthroughClassifierDefaultAlt() async throws {
        let classifier = PassthroughClassifier()
        let result = try await classifier.classify(Data())
        XCTAssertEqual(result, .regularImage(altText: "Image"))
    }

    func testPassthroughClassifierCustomAlt() async throws {
        let classifier = PassthroughClassifier(defaultAltText: "Custom")
        let result = try await classifier.classify(Data())
        XCTAssertEqual(result, .regularImage(altText: "Custom"))
    }

    func testPassthroughClassifierLatexThrows() async {
        let classifier = PassthroughClassifier()
        do {
            _ = try await classifier.convertToLatex(Data())
            XCTFail("Expected error to be thrown")
        } catch {
            XCTAssertTrue(error is ImageClassifierError)
        }
    }
}
