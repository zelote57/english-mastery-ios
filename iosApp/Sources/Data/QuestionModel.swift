// QuestionModel.swift
// SwiftData representation of a curriculum question.

import Foundation
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

    public init(
        id: UUID = UUID(),
        skillId: UUID,
        prompt: String,
        correctAnswer: String,
        acceptedSynonyms: [String] = [],
        distractors: [String] = [],
        questionType: String,
        isPlacementEligible: Bool = false
    ) {
        self.id = id
        self.skillId = skillId
        self.prompt = prompt
        self.correctAnswer = correctAnswer
        self.acceptedSynonymsJSON = (try? String(data: JSONEncoder().encode(acceptedSynonyms), encoding: .utf8)) ?? "[]"
        self.distractorsJSON      = (try? String(data: JSONEncoder().encode(distractors),      encoding: .utf8)) ?? "[]"
        self.questionType = questionType
        self.isPlacementEligible = isPlacementEligible
    }

    public var acceptedSynonyms: [String] {
        (try? JSONDecoder().decode([String].self, from: Data(acceptedSynonymsJSON.utf8))) ?? []
    }
    public var distractors: [String] {
        (try? JSONDecoder().decode([String].self, from: Data(distractorsJSON.utf8))) ?? []
    }
}
