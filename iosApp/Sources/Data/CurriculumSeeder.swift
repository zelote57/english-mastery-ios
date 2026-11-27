import Foundation
import SwiftData

/// Reads the bundled JSON seed file and populates the SwiftData store with
/// `Chunk` objects (and, later, Phase/Skill/Question models). This runs once at
/// app launch if the store is empty.
public struct CurriculumSeeder {
    private let bundle = Bundle.main
    private let seedFileName = "seed-curriculum"
    private let seedFileExtension = "json"

    public init() {}

    /// Load the JSON file, decode into simple structs, and insert chunks.
    public func seedIfNeeded() async throws {
        // Obtain a context from the shared container.
        let context = DataLayer.container.mainContext
        // Simple guard – if any Chunk already exists we assume seeding was done.
        if try context.fetchCount(FetchDescriptor<Chunk>()) > 0 { return }

        guard let url = bundle.url(forResource: seedFileName, withExtension: seedFileExtension) else {
            throw SeedError.fileNotFound
        }
        let data = try Data(contentsOf: url)
        let seed = try JSONDecoder().decode(SeedRoot.self, from: data)

        // Insert phases, skills, questions (as plain structs – not SwiftData models yet).
        // For now we only create Chunk entries for each question.
        for question in seed.questions {
            let text = "\(question.prompt) – Answer: \(question.correctAnswer)"
            // Insert chunk asynchronously – embedder uses async Gemini call.
            try await VectorStore.insertChunk(text: text, questionId: question.id, in: context)
        }
    }

    // MARK: - Seed data structures (mirroring the JSON layout)
    struct SeedRoot: Codable {
        let phases: [PhaseSeed]
        let skills: [SkillSeed]
        let questions: [QuestionSeed]
    }
    struct PhaseSeed: Codable { let id: UUID; let level: String; let title: String; let cambridgeAlignment: String; let order: Int; let status: String }
    struct SkillSeed: Codable { let id: UUID; let skillCode: String; let topic: String; let phaseId: UUID }
    struct QuestionSeed: Codable {
        let id: UUID
        let skillId: UUID
        let prompt: String
        let correctAnswer: String
        let acceptedSynonyms: [String]
        let distractors: [String]
        let questionType: String
        let isPlacementEligible: Bool
    }

    enum SeedError: Error { case fileNotFound }
}
