import Foundation

/// Ephemeral reinforcement session for `"Practice Missed Questions"`.
/// Intentionally holds no references to `User`, `Phase`, `Skill`, or `Attempt` to enforce Drill Score Isolation.
struct MistakeDrillUseCase: Equatable, Sendable {
    private(set) var remainingQuestions: [Question]
    private(set) var completedCount: Int = 0
    let totalMissedCount: Int

    var currentQuestion: Question? { remainingQuestions.first }
    var isCompleted: Bool { remainingQuestions.isEmpty }

    init(attempt: Attempt, questions: [Question]) {
        let questionsById = Dictionary(
            questions.map { ($0.id, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        var seenIds = Set<UUID>()
        let missed = attempt.answers
            .filter { $0.pointsEarned == 0.0 }
            .compactMap { record -> Question? in
                guard seenIds.insert(record.questionId).inserted else { return nil }
                return questionsById[record.questionId]
            }

        self.remainingQuestions = missed
        self.totalMissedCount = missed.count
    }

    /// Evaluates one drill attempt; removes the question on an exact (`+1.0`) match or rotates it for retry.
    mutating func submit(answer: String) -> Bool {
        guard let current = remainingQuestions.first else { return false }
        let result = ScoringEngine.grade(answer: answer, for: current)

        if result.isCorrect {
            remainingQuestions.removeFirst()
            completedCount += 1
            return true
        }

        if remainingQuestions.count > 1 {
            remainingQuestions.append(remainingQuestions.removeFirst())
        }
        return false
    }
}
