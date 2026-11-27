import Foundation
import SwiftData

/// SwiftData persistence model for an official `skillAssessment` or `placementTest` attempt (`specs/04-data-models.json`).
@Model
final class AttemptModel {
    @Attribute(.unique) var id: UUID
    var userId: UUID
    var skillId: UUID?
    var attemptType: String
    var score: Double
    var earnedPoints: Double
    var totalQuestions: Int
    var correctAnswers: Int
    var timestamp: Date
    @Relationship(deleteRule: .cascade, inverse: \AnswerRecordModel.attempt) var answers: [AnswerRecordModel] = []

    init(
        id: UUID = UUID(),
        userId: UUID,
        skillId: UUID? = nil,
        attemptType: String = AttemptType.skillAssessment.rawValue,
        score: Double,
        earnedPoints: Double,
        totalQuestions: Int,
        correctAnswers: Int,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.userId = userId
        self.skillId = skillId
        self.attemptType = attemptType
        self.score = score
        self.earnedPoints = earnedPoints
        self.totalQuestions = totalQuestions
        self.correctAnswers = correctAnswers
        self.timestamp = timestamp
    }

    convenience init(from attempt: Attempt) {
        self.init(
            id: attempt.id,
            userId: attempt.userId,
            skillId: attempt.skillId,
            attemptType: attempt.attemptType.rawValue,
            score: attempt.score,
            earnedPoints: attempt.earnedPoints,
            totalQuestions: attempt.totalQuestions,
            correctAnswers: attempt.correctAnswers,
            timestamp: attempt.timestamp
        )
        self.answers = attempt.answers.map { AnswerRecordModel(from: $0) }
    }

    func toDomain() -> Attempt? {
        guard let parsedType = AttemptType(rawValue: attemptType) else {
            return nil
        }
        return Attempt(
            id: id,
            userId: userId,
            skillId: skillId,
            attemptType: parsedType,
            score: score,
            earnedPoints: earnedPoints,
            totalQuestions: totalQuestions,
            correctAnswers: correctAnswers,
            timestamp: timestamp,
            answers: answers.map { $0.toDomain() }
        )
    }
}
