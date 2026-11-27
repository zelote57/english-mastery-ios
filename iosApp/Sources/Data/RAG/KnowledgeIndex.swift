import Foundation

actor KnowledgeIndex {
    private let embedding: any EmbeddingProvider
    private let store = VectorStore()

    init(embedding: any EmbeddingProvider = NaturalLanguageEmbedding()) {
        self.embedding = embedding
    }

    func index(_ chunks: [KnowledgeChunk]) async throws {
        var entries: [IndexedChunk] = []
        for chunk in chunks {
            let vector = try await embedding.embed(chunk.content)
            entries.append(IndexedChunk(chunk: chunk, vector: vector))
        }
        try await store.replace(with: entries)
    }

    func search(_ query: String, level: PhaseLevel? = nil, topic: String? = nil) async throws -> [KnowledgeChunk] {
        let vector = try await embedding.embed(query)
        return try await store.search(vector: vector, level: level, topic: topic)
    }
}
