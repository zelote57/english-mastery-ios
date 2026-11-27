import XCTest
import SwiftData
@testable import EnglishMastery

final class RAGTests: XCTestCase {
    var container: ModelContainer!
    var context: ModelContext { container.mainContext }

    override func setUpWithError() throws {
        let schema = Schema([
            Chunk.self,
            PhaseModel.self,
            SkillModel.self,
            QuestionModel.self,
            UserModel.self
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: [config])
    }

    func testEmbeddingGeneration() async throws {
        let data = try await DataLayer.embedder.embed("sample text")
        let vec = try data.decodeEmbedding()
        XCTAssertFalse(vec.isEmpty, "Embedding should contain values")
    }

    func testInsertAndSearchChunk() async throws {
        let text = "test chunk"
        let mockVec: [Double] = [1, 1, 1]
        let mockData = try JSONEncoder().encode(mockVec)
        let chunk = Chunk(text: text, embedding: mockData, questionId: nil)
        context.insert(chunk)
        try context.save()

        let results = try await VectorStore.search(query: "any query", topK: 1, in: context)
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.text, text)
    }
}
