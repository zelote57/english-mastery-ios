import Foundation

/// Errors raised when onboarding or placement preconditions cannot be satisfied.
enum PlacementError: Error, Equatable, Sendable {
    case emptyPhases
}

/// Resulting phase assignments and optional placement `Attempt` after onboarding routing.
struct PlacementOutcome: Equatable, Sendable {
    let attempt: Attempt?
    let targetPhase: Phase
    let updatedUser: User
    let updatedPhases: [Phase]
}

/// Routes a learner to Phase 1 (`Start from Scratch`) or Phase K via sequential `>= 1.5` placement.
enum PlacementEvaluationUseCase: Sendable {
    static let phasePassThreshold = 1.5

    static func startFromScratch(user: User, phases: [Phase]) throws -> PlacementOutcome {
        var ordered = phases.sorted { $0.order < $1.order }
        guard !ordered.isEmpty else { throw PlacementError.emptyPhases }

        for index in ordered.indices {
            ordered[index].status = index == 0 ? .available : .locked
        }

        var updatedUser = user
        updatedUser.currentPhaseId = ordered[0].id
        updatedUser.placementPhaseCode = nil
        updatedUser.hasCompletedOnboarding = true

        return PlacementOutcome(
            attempt: nil,
            targetPhase: ordered[0],
            updatedUser: updatedUser,
            updatedPhases: ordered
        )
    }

    static func evaluatePlacement(
        user: User,
        phases: [Phase],
        skills: [Skill],
        submissions: [QuestionSubmission],
        now: Date = Date(),
        attemptId: UUID = UUID()
    ) throws -> PlacementOutcome {
        var ordered = phases.sorted { $0.order < $1.order }
        guard !ordered.isEmpty else { throw PlacementError.emptyPhases }

        // Placement test suppresses mid-test RAG sheets, so drop any diagnostic feedback.
        let sanitizedSubmissions = submissions.map {
            QuestionSubmission(question: $0.question, userAnswer: $0.userAnswer, ragFeedback: nil)
        }
        let attempt = ScoringEngine.buildAttempt(
            from: sanitizedSubmissions,
            userId: user.id,
            skillId: nil,
            attemptType: .placementTest,
            timestamp: now,
            attemptId: attemptId
        )

        let phaseBySkillId = Dictionary(
            skills.map { ($0.id, $0.phaseId) },
            uniquingKeysWith: { first, _ in first }
        )

        var pointsByPhaseId: [UUID: Double] = [:]
        for (submission, record) in zip(sanitizedSubmissions, attempt.answers) {
            if let phaseId = phaseBySkillId[submission.question.skillId] {
                pointsByPhaseId[phaseId, default: 0.0] += record.pointsEarned
            }
        }

        let targetIndex = ordered.firstIndex { phase in
            (pointsByPhaseId[phase.id] ?? 0.0) < phasePassThreshold
        } ?? (ordered.count - 1)

        for index in ordered.indices {
            if index < targetIndex {
                ordered[index].status = .skippedPassed
            } else if index == targetIndex {
                ordered[index].status = .available
            } else {
                ordered[index].status = .locked
            }
        }

        let targetPhase = ordered[targetIndex]
        var updatedUser = user
        updatedUser.currentPhaseId = targetPhase.id
        updatedUser.placementPhaseCode = targetPhase.level
        updatedUser.hasCompletedOnboarding = true

        return PlacementOutcome(
            attempt: attempt,
            targetPhase: targetPhase,
            updatedUser: updatedUser,
            updatedPhases: ordered
        )
    }
}
