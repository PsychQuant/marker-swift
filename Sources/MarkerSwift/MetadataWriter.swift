import Foundation

/// Writes document metadata to JSON format
public struct MetadataWriter {
    private let encoder: JSONEncoder

    public init() {
        encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
    }

    /// Encode metadata to JSON data
    /// - Parameter document: The document metadata to encode
    /// - Returns: JSON data
    public func encode(_ document: MarkerDocument) throws -> Data {
        try encoder.encode(document)
    }

    /// Encode metadata to JSON string
    /// - Parameter document: The document metadata to encode
    /// - Returns: JSON string
    public func encodeToString(_ document: MarkerDocument) throws -> String {
        let data = try encode(document)
        guard let string = String(data: data, encoding: .utf8) else {
            throw MetadataWriterError.encodingFailed
        }
        return string
    }

    /// Write metadata to file
    /// - Parameters:
    ///   - document: The document metadata
    ///   - url: File URL to write to
    public func write(_ document: MarkerDocument, to url: URL) throws {
        let data = try encode(document)
        try data.write(to: url)
    }
}

/// Errors from MetadataWriter
public enum MetadataWriterError: Error, LocalizedError {
    case encodingFailed

    public var errorDescription: String? {
        switch self {
        case .encodingFailed:
            return "Failed to encode metadata to UTF-8 string"
        }
    }
}
