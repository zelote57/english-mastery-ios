import Foundation
import SwiftData
import GenerativeAI

/// Simple in‑memory vector store that persists `Chunk` entities via SwiftData.
/// It provides insertion of a chunk (including embedding generation) and
/// cosine‑similarity search for the top‑K most relevant chunks.
public struct VectorStore {
    // MARK: - Insertion
    /// Generates an embedding for the given text using the global embedder
    /// (`DataLayer.embedder`) and inserts a `Chunk` into the supplied context.
    public static func insertChunk(text: String, questionId: UUID?, in context: ModelContext) async throws {
        // Obtain embedding from the Gemini provider (JSON‑encoded Data).
        let embeddingData = try await DataLayer.embedder.embed(text)
        let chunk = Chunk(text: text, embedding: embeddingData, question: nil)
        // Optionally link to the owning question via its UUID.
        if let qId = questionId {
            // Resolve the Question entity (if it exists) and set relationship.
            if var question = try? context.fetch(FetchDescriptor<Question>(predicate: #Predicate { $0.id == qId }))?.first {
                // Establish relationship – SwiftData automatically tracks inverse.
                question.chunks.append(chunk)
                context.insert(question)
            }
        }
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
        // 3️⃣ Compute cosine similarity.
        let scored = allChunks.map { chunk -> (Chunk, Double) in
            let vec = try? chunk.embedding.decodeEmbedding()
            let sim = cosineSimilarity(queryVector, vec ?? [])
            return (chunk, sim)
        }
        // 4️⃣ Sort and pick top‑K.
        let top = scored.sorted(by: { $0.1 > $1.1 }).prefix(topK).map { $0.0 }
        return Array(top)
    }

    // MARK: - Helpers
    private static func cosineSimilarity(_ a: [Double], _ b: [Double]) -> Double {
        guard !a.isEmpty && a.count == b.count else { return 0 }
        var dot = 0.0
        var normA = 0.0
        var normB = 0.0
        for i in 0..<a.count {
            dot += a[i] * b[i]
            normA += a[i] * a[i]
            normB += b[i] * b[i]
        }
        let denom = (sqrt(normA) * sqrt(normB))
        return denom > 0 ? dot / denom : 0
    }
}
