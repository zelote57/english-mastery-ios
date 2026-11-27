import Foundation
import SwiftData

/// SwiftData persistence model for an assessment question (`specs/04-data-models.json`).
/// Stores string arrays JSON-encoded to remain compatible with iOS 17 SwiftData.
@Model
final class QuestionModel {
    @Attribute(.unique) var id: UUID
    var skillId: UUID
    var prompt: String
    var correctAnswer: String
    var acceptedSynonymsJSON: String
    var distractorsJSON: String
    var questionType: String
    var isPlacementEligible: Bool
    var skill: SkillModel?

    init(
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
        self.acceptedSynonymsJSON = Self.encodeStringArray(acceptedSynonyms)
        self.distractorsJSON = Self.encodeStringArray(distractors)
        self.questionType = questionType
        self.isPlacementEligible = isPlacementEligible
        self.skill = skill
    }

    convenience init(from question: Question, skill: SkillModel? = nil) {
        self.init(
            id: question.id,
            skillId: question.skillId,
            prompt: question.prompt,
            correctAnswer: question.correctAnswer,
            acceptedSynonyms: question.acceptedSynonyms,
            distractors: question.distractors,
            questionType: question.questionType.rawValue,
            isPlacementEligible: question.isPlacementEligible,
            skill: skill
        )
    }

    func toDomain() -> Question? {
        guard let parsedType = QuestionType(rawValue: questionType),
              let acceptedSynonyms = Self.decodeStringArray(acceptedSynonymsJSON),
              let distractors = Self.decodeStringArray(distractorsJSON) else {
            return nil
        }
        return Question(
            id: id,
            skillId: skillId,
            prompt: prompt,
            correctAnswer: correctAnswer,
            acceptedSynonyms: acceptedSynonyms,
            distractors: distractors,
            questionType: parsedType,
            isPlacementEligible: isPlacementEligible
        )
    }

    private static func encodeStringArray(_ values: [String]) -> String {
        guard let data = try? JSONEncoder().encode(values),
              let json = String(data: data, encoding: .utf8) else {
            return "[]"
        }
        return json
    }

    func updateContent(from question: Question) {
        prompt = question.prompt
        correctAnswer = question.correctAnswer
        acceptedSynonymsJSON = Self.encodeStringArray(question.acceptedSynonyms)
        distractorsJSON = Self.encodeStringArray(question.distractors)
        questionType = question.questionType.rawValue
        isPlacementEligible = question.isPlacementEligible
    }

    private static func decodeStringArray(_ json: String) -> [String]? {
        guard let data = json.data(using: .utf8),
              let values = try? JSONDecoder().decode([String].self, from: data) else {
            return nil
        }
        return values
    }
}
