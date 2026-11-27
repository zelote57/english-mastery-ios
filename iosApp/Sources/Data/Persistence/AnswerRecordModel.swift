import Foundation
import SwiftData

/// SwiftData persistence model for one graded response inside an official `AttemptModel` (`specs/04-data-models.json`).
@Model
final class AnswerRecordModel {
    @Attribute(.unique) var id: UUID
    var attemptId: UUID
    var questionId: UUID
    var userAnswer: String
    var pointsEarned: Double
    var isCorrect: Bool
    var ragFeedback: String?
    var attempt: AttemptModel?

    init(
        id: UUID = UUID(),
        attemptId: UUID,
        questionId: UUID,
        userAnswer: String,
        pointsEarned: Double,
        ragFeedback: String? = nil,
        attempt: AttemptModel? = nil
    ) {
        self.id = id
        self.attemptId = attemptId
        self.questionId = questionId
        self.userAnswer = userAnswer
        self.pointsEarned = pointsEarned
        self.isCorrect = pointsEarned == 1.0
        self.ragFeedback = pointsEarned == 0.0 ? ragFeedback : nil
        self.attempt = attempt
    }

    convenience init(from record: AnswerRecord, attempt: AttemptModel? = nil) {
        self.init(
            id: record.id,
            attemptId: record.attemptId,
            questionId: record.questionId,
            userAnswer: record.userAnswer,
            pointsEarned: record.pointsEarned,
            ragFeedback: record.ragFeedback,
            attempt: attempt
        )
    }

    func toDomain() -> AnswerRecord {
        AnswerRecord(
            id: id,
            attemptId: attemptId,
            questionId: questionId,
            userAnswer: userAnswer,
            pointsEarned: pointsEarned,
            ragFeedback: ragFeedback
        )
    }
}
