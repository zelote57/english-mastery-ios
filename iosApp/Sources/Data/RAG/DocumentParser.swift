import Foundation
import PDFKit

enum DocumentParser {
    enum ParseError: Error, Equatable {
        case unsupportedFormat(String)
        case invalidPDF
        case emptyDocument
    }

    static func parse(url: URL, level: PhaseLevel, topic: String, sourceFile: String? = nil) throws -> [KnowledgeChunk] {
        let text: String
        switch url.pathExtension.lowercased() {
        case "md":
            text = try String(contentsOf: url, encoding: .utf8)
        case "pdf":
            guard let document = PDFDocument(url: url), let extracted = document.string else {
                throw ParseError.invalidPDF
            }
            text = extracted
        default:
            throw ParseError.unsupportedFormat(url.pathExtension)
        }
        let chunks = DocumentChunker.split(
            text, sourceFile: sourceFile ?? url.lastPathComponent, level: level, topic: topic
        )
        guard !chunks.isEmpty else { throw ParseError.emptyDocument }
        return chunks
    }
}
