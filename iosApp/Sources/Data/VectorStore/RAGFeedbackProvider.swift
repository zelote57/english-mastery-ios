import SwiftData
import Foundation

/// Public helper that retrieves the most relevant chunks for a query and
/// concatenates their text. Intended to be called when the app needs RAG
/// feedback for an incorrect answer.
public struct RAGFeedbackProvider {
    /// Retrieves top‑K chunks and returns a single string with their texts.
    public static func feedback(for query: String, topK: Int = 3) async throws -> String {
        let context = DataLayer.container.mainContext
        let chunks = try await VectorStore.search(query: query, topK: topK, in: context)
        // Join the chunk texts with a separator for readability.
        return chunks.map { $0.text }.joined(separator: "\n---\n")
    }
}
