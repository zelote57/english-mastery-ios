import Foundation
import SwiftData

/// Simple in‑memory vector store that persists `Chunk` entities via SwiftData.
/// It provides insertion of a chunk (including embedding generation) and
/// cosine‑similarity search for the top‑K most relevant chunks.
public struct VectorStore {
    // MARK: - Insertion
    /// Generates an embedding for the given text using the global embedder
    /// (`DataLayer.embedder`) and inserts a `Chunk` into the supplied context.
    public static func insertChunk(text: String, questionId: UUID?, in context: ModelContext) async throws {
        let embeddingData = try await DataLayer.embedder.embed(text)
        let chunk = Chunk(text: text, embedding: embeddingData, questionId: questionId)
        context.insert(chunk)
        try context.save()
    }

    // MARK: - Search
    /// Searches the stored chunks for the top‑K most similar to the query text.
    /// Returns the matching `Chunk` instances ordered by descending similarity.
    public static func search(query: String, topK: Int = 3, in context: ModelContext) async throws -> [Chunk] {
        // 1️⃣ Embed the query.
        let queryEmbeddingData = try await DataLayer.embedder.embed(query)
        let queryVector = try queryEmbeddingData.decodeEmbedding()

        // 2️⃣ Load all chunks (in‑memory for the prototype).
        let allChunks = try context.fetch(FetchDescriptor<Chunk>())

        // 3️⃣ Compute cosine similarity and pick top‑K.
        let top = allChunks
            .map { chunk -> (Chunk, Double) in
                let vec = (try? chunk.embedding.decodeEmbedding()) ?? []
                return (chunk, cosineSimilarity(queryVector, vec))
            }
            .sorted { $0.1 > $1.1 }
            .prefix(topK)
            .map { $0.0 }
        return Array(top)
    }

    // MARK: - Helpers
    private static func cosineSimilarity(_ a: [Double], _ b: [Double]) -> Double {
        guard !a.isEmpty && a.count == b.count else { return 0 }
        var dot = 0.0, normA = 0.0, normB = 0.0
        for i in 0..<a.count {
            dot   += a[i] * b[i]
            normA += a[i] * a[i]
            normB += b[i] * b[i]
        }
        let denom = sqrt(normA) * sqrt(normB)
        return denom > 0 ? dot / denom : 0
    }
}
