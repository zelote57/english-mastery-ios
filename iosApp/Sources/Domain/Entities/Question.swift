import Foundation

/// Supported assessment interaction modes.
enum QuestionType: String, Codable, Sendable {
    case multipleChoice
    case fillBlank
    case translation
    case reorder
}

/// Assessment question belonging to a curriculum skill.
struct Question: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    let skillId: UUID
    let prompt: String
    let correctAnswer: String
    let acceptedSynonyms: [String]
    let distractors: [String]
    let questionType: QuestionType
    let isPlacementEligible: Bool

    init(
        id: UUID = UUID(),
        skillId: UUID,
        prompt: String,
        correctAnswer: String,
        acceptedSynonyms: [String] = [],
        distractors: [String] = [],
        questionType: QuestionType,
        isPlacementEligible: Bool = false
    ) {
        self.id = id
        self.skillId = skillId
        self.prompt = prompt
        self.correctAnswer = correctAnswer
        self.acceptedSynonyms = acceptedSynonyms
        self.distractors = distractors
        self.questionType = questionType
        self.isPlacementEligible = isPlacementEligible
    }
}
