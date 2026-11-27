import Foundation

/// Distinguishes official 15-question skill assessments from the 18-question placement test.
enum AttemptType: String, Codable, Sendable {
    case skillAssessment
    case placementTest
}

/// Persisted record of an official skill or placement assessment.
struct Attempt: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    let userId: UUID
    let skillId: UUID?
    let attemptType: AttemptType
    let score: Double
    let earnedPoints: Double
    let totalQuestions: Int
    let correctAnswers: Int
    let timestamp: Date
    var answers: [AnswerRecord]

    init(
        id: UUID = UUID(),
        userId: UUID,
        skillId: UUID?,
        attemptType: AttemptType = .skillAssessment,
        score: Double,
        earnedPoints: Double,
        totalQuestions: Int,
        correctAnswers: Int,
        timestamp: Date = Date(),
        answers: [AnswerRecord] = []
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
        self.answers = answers
    }

    /// Returns up to `limit` most recent official attempts for `skillId`, ordered chronologically.
    static func recentSkillAttempts(
        for skillId: UUID,
        in attempts: [Attempt],
        limit: Int = 5
    ) -> [Attempt] {
        guard limit > 0 else { return [] }
        return attempts
            .filter { $0.attemptType == .skillAssessment && $0.skillId == skillId }
            .sorted { $0.timestamp < $1.timestamp }
            .suffix(limit)
            .map { $0 }
    }
}
