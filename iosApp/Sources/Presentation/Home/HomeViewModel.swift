import Foundation
import Observation

@Observable
@MainActor
final class HomeViewModel {
    private let coordinator: AppCoordinator

    init(coordinator: AppCoordinator) {
        self.coordinator = coordinator
    }

    var user: User? { coordinator.currentUser }
    var phases: [Phase] { coordinator.phases.sorted { $0.order < $1.order } }
    var skills: [Skill] { coordinator.skills }
    var attempts: [Attempt] { coordinator.attempts }

    var overallProgressFraction: Double {
        guard !skills.isEmpty else { return 0.0 }
        let passed = skills.filter(\.isPassed).count
        return Double(passed) / Double(skills.count)
    }

    func skills(for phase: Phase) -> [Skill] {
        skills
            .filter { $0.phaseId == phase.id }
            .sorted { $0.skillCode < $1.skillCode }
    }

    func displayState(skill: Skill, phase: Phase) -> SkillDisplayState {
        skill.displayState(in: phase)
    }

    func recentAttempts(for skill: Skill) -> [Attempt] {
        Attempt.recentSkillAttempts(for: skill.id, in: attempts)
    }

    func openSkill(_ skill: Skill) {
        coordinator.openSkill(skill)
    }
}
