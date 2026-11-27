// QuestionModel.swift
// SwiftData representation of a curriculum question.

import SwiftData

@Model
public final class QuestionModel {
    @Attribute(.unique) public var id: UUID
    public var skillId: UUID
    public var prompt: String
    public var correctAnswer: String
    public var acceptedSynonymsJSON: String // JSON‑encoded [String]
    public var distractorsJSON: String      // JSON‑encoded [String]
    public var questionType: String
    public var isPlacementEligible: Bool
    // Relationship to owning skill (inverse defined in SkillModel).
    @Relationship(inverse: "questions") public var skill: SkillModel?
    // Relationship to its chunks.
    @Relationship(inverse: "questionId") public var chunks: [Chunk] = []

    public init(
        id: UUID = UUID(),
        skillId: UUID,
        prompt: String,
        correctAnswer: String,
        acceptedSynonyms: [String] = [],
        distractors: [String] = [],
        questionType: String,
        isPlacementEligible: Bool = false,
        skill: SkillModel? = nil
    ) {
        self.id = id
        self.skillId = skillId
        self.prompt = prompt
        self.correctAnswer = correctAnswer
        let synonymsData = try! JSONEncoder().encode(acceptedSynonyms)
        self.acceptedSynonymsJSON = String(data: synonymsData, encoding: .utf8) ?? "[]"
        let distractorsData = try! JSONEncoder().encode(distractors)
        self.distractorsJSON = String(data: distractorsData, encoding: .utf8) ?? "[]"
        self.questionType = questionType
        self.isPlacementEligible = isPlacementEligible
        self.skill = skill
    }

    // Helper to decode synonyms/distractors when needed.
    public var acceptedSynonyms: [String] {
        (try? JSONDecoder().decode([String].self, from: Data(acceptedSynonymsJSON.utf8))) ?? []
    }
    public var distractors: [String] {
        (try? JSONDecoder().decode([String].self, from: Data(distractorsJSON.utf8))) ?? []
    }
}
