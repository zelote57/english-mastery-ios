import Foundation

/// Updated progression state emitted after completing an official `skillAssessment` attempt.
struct AttemptEvaluationOutcome: Equatable, Sendable {
    let attempt: Attempt
    let updatedUser: User
    let updatedSkill: Skill
    let updatedPhases: [Phase]
    let didCompleteActivePhase: Bool
    let unlockedPhase: Phase?
}

/// Grades an official skill assessment, updates monotonic mastery and streak, and advances phases.
enum EvaluateAttemptUseCase: Sendable {
    static let masteryThreshold = 0.80

    static func evaluate(
        user: User,
        skill: Skill,
        phases: [Phase],
        skills: [Skill],
        submissions: [QuestionSubmission],
        now: Date = Date(),
        calendar: Calendar = .current,
        attemptId: UUID = UUID()
    ) -> AttemptEvaluationOutcome {
        let attempt = ScoringEngine.buildAttempt(
            from: submissions,
            userId: user.id,
            skillId: skill.id,
            attemptType: .skillAssessment,
            timestamp: now,
            attemptId: attemptId
        )

        var updatedSkill = skill
        if attempt.score > updatedSkill.bestScore {
            updatedSkill.bestScore = attempt.score
        }
        if updatedSkill.bestScore >= masteryThreshold {
            updatedSkill.isPassed = true
        }

        var updatedUser = user
        updatedUser.recordPractice(at: now, calendar: calendar)

        let mergedSkills = skills.map { $0.id == updatedSkill.id ? updatedSkill : $0 }
        var updatedPhases = phases.sorted { $0.order < $1.order }
        var didCompleteActivePhase = false
        var unlockedPhase: Phase?

        // Optional practice in skippedPassed or already-completed phases never moves currentPhaseId.
        if updatedSkill.phaseId == updatedUser.currentPhaseId,
           let activeIndex = updatedPhases.firstIndex(where: { $0.id == updatedUser.currentPhaseId }) {
            let phaseSkills = mergedSkills.filter { $0.phaseId == updatedPhases[activeIndex].id }
            if !phaseSkills.isEmpty && phaseSkills.allSatisfy(\.isPassed) {
                updatedPhases[activeIndex].status = .completed
                didCompleteActivePhase = true

                let nextIndex = activeIndex + 1
                if updatedPhases.indices.contains(nextIndex) {
                    if updatedPhases[nextIndex].status == .locked {
                        updatedPhases[nextIndex].status = .available
                    }
                    updatedUser.currentPhaseId = updatedPhases[nextIndex].id
                    unlockedPhase = updatedPhases[nextIndex]
                }
            }
        }

        return AttemptEvaluationOutcome(
            attempt: attempt,
            updatedUser: updatedUser,
            updatedSkill: updatedSkill,
            updatedPhases: updatedPhases,
            didCompleteActivePhase: didCompleteActivePhase,
            unlockedPhase: unlockedPhase
        )
    }
}
