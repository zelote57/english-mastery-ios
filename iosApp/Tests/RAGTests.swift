import XCTest
import SwiftData
@testable import EnglishMastery

final class RAGTests: XCTestCase {
    // Helper to create a fresh in‑memory container for isolation.
    var container: ModelContainer!
    var context: ModelContext { container.mainContext }

    override func setUpWithError() throws {
        // Define the same schema as the app.
        let schema = Schema([
            Chunk.self,
            PhaseModel.self,
            SkillModel.self,
            QuestionModel.self,
            User.self
        ])
        container = try ModelContainer(for: schema, configurations: [])
        // Ensure a clean state.
        try context.deleteAll()
    }

    func testEmbeddingGeneration() async throws {
        let data = try await DataLayer.embedder.embed("sample text")
        let vec = try data.decodeEmbedding()
        XCTAssertFalse(vec.isEmpty, "Embedding should contain values")
    }

    func testInsertAndSearchChunk() async throws {
        // Insert a chunk with a known vector (e.g., all ones).
        let text = "test chunk"
        // Mock embedding: 3‑dim vector of ones encoded as JSON.
        let mockVec: [Double] = [1, 1, 1]
        let mockData = try JSONEncoder().encode(mockVec)
        let chunk = Chunk(text: text, embedding: mockData, questionId: nil)
        context.insert(chunk)
        try context.save()

        // Search with identical query should return the same chunk.
        let results = try await VectorStore.search(query: "any query", topK: 1, in: context)
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.text, text)
    }
}
