import Foundation

/// Graded answer for a single question within an official assessment attempt.
struct AnswerRecord: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    let attemptId: UUID
    let questionId: UUID
    let userAnswer: String
    let pointsEarned: Double
    let isCorrect: Bool
    var ragFeedback: String?

    init(
        id: UUID = UUID(),
        attemptId: UUID,
        questionId: UUID,
        userAnswer: String,
        pointsEarned: Double,
        ragFeedback: String? = nil
    ) {
        self.id = id
        self.attemptId = attemptId
        self.questionId = questionId
        self.userAnswer = userAnswer
        self.pointsEarned = pointsEarned
        self.isCorrect = pointsEarned == 1.0
        self.ragFeedback = pointsEarned == 0.0 ? ragFeedback : nil
    }
}
