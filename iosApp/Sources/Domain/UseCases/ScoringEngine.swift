import Foundation

/// Outcome of grading a single learner response against a question rubric.
struct GradeResult: Equatable, Sendable {
    let pointsEarned: Double

    var isCorrect: Bool { pointsEarned == 1.0 }
}

/// Learner response paired with its question and optional RAG explanation (for `0.0` misses).
struct QuestionSubmission: Equatable, Sendable {
    let question: Question
    let userAnswer: String
    let ragFeedback: String?

    init(question: Question, userAnswer: String, ragFeedback: String? = nil) {
        self.question = question
        self.userAnswer = userAnswer
        self.ragFeedback = ragFeedback
    }
}

enum ScoringEngine: Sendable {
    /// Normalizes whitespace, case, typographic apostrophes, and optional trailing `.?!` punctuation.
    static func normalize(_ text: String, stripTerminalPunctuation: Bool) -> String {
        let unifiedApostrophes = text
            .replacingOccurrences(of: "\u{2018}", with: "'")
            .replacingOccurrences(of: "\u{2019}", with: "'")
            .replacingOccurrences(of: "\u{02BC}", with: "'")
            .replacingOccurrences(of: "`", with: "'")
            .lowercased()

        var normalized = unifiedApostrophes
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")

        if stripTerminalPunctuation {
            while let last = normalized.last,
                  last == "." || last == "?" || last == "!" || last.isWhitespace {
                normalized.removeLast()
            }
        }
        return normalized
    }

    /// Evaluates one learner response deterministically with zero AI inference.
    static func grade(answer: String, for question: Question) -> GradeResult {
        let normalizedAnswer = normalize(answer, stripTerminalPunctuation: true)
        guard !normalizedAnswer.isEmpty else {
            return GradeResult(pointsEarned: 0.0)
        }

        let candidates = ([question.correctAnswer] + question.acceptedSynonyms)
            .map { normalize($0, stripTerminalPunctuation: true) }
            .filter { !$0.isEmpty }

        return GradeResult(pointsEarned: candidates.contains(normalizedAnswer) ? 1.0 : 0.0)
    }

    /// Grades all submissions and constructs an `Attempt` with linked `AnswerRecord` entries.
    static func buildAttempt(
        from submissions: [QuestionSubmission],
        userId: UUID,
        skillId: UUID?,
        attemptType: AttemptType,
        timestamp: Date = Date(),
        attemptId: UUID = UUID()
    ) -> Attempt {
        let records = submissions.map { submission in
            let result = grade(answer: submission.userAnswer, for: submission.question)
            return AnswerRecord(
                attemptId: attemptId,
                questionId: submission.question.id,
                userAnswer: submission.userAnswer,
                pointsEarned: result.pointsEarned,
                ragFeedback: submission.ragFeedback
            )
        }

        let earnedPoints = records.reduce(0.0) { $0 + $1.pointsEarned }
        let correctAnswers = records.count { $0.isCorrect }
        let score = submissions.isEmpty ? 0.0 : earnedPoints / Double(submissions.count)

        return Attempt(
            id: attemptId,
            userId: userId,
            skillId: skillId,
            attemptType: attemptType,
            score: score,
            earnedPoints: earnedPoints,
            totalQuestions: submissions.count,
            correctAnswers: correctAnswers,
            timestamp: timestamp,
            answers: records
        )
    }
}
