import Foundation

/// Visual progression state derived from skill mastery and parent phase status.
enum SkillDisplayState: Equatable, Sendable {
    case passed
    case skippedPassed
    case available
    case locked
}

/// Individual grammar or Use of English skill within a Cambridge phase.
struct Skill: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    let skillCode: String
    let topic: String
    let phaseId: UUID
    var isPassed: Bool
    var bestScore: Double

    init(
        id: UUID = UUID(),
        skillCode: String,
        topic: String,
        phaseId: UUID,
        isPassed: Bool = false,
        bestScore: Double = 0.0
    ) {
        self.id = id
        self.skillCode = skillCode
        self.topic = topic
        self.phaseId = phaseId
        self.isPassed = isPassed
        self.bestScore = bestScore
    }

    /// Computes the UI progression state for this skill given its owning phase.
    func displayState(in phase: Phase) -> SkillDisplayState {
        if isPassed { return .passed }
        switch phase.status {
        case .skippedPassed: return .skippedPassed
        case .available, .completed: return .available
        case .locked: return .locked
        }
    }
}
