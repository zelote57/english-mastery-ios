import Foundation
import Observation
import SwiftData

/// Root `@Observable @MainActor` coordinator managing SwiftData state, domain snapshots, and `AppState` transitions.
@Observable
@MainActor
final class AppCoordinator {
    private let modelContext: ModelContext

    var appState: AppState = .gatingModel
    var modelGateStatus: ModelGateStatus = .loading
    var currentUser: User?
    var phases: [Phase] = []
    var skills: [Skill] = []
    var questions: [Question] = []
    var attempts: [Attempt] = []
    var placementQuestions: [Question] = []
    var activeSkill: Skill?
    var activeAttempt: Attempt?
    var errorMessage: String?

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    /// Loads curriculum snapshots from SwiftData and routes out of `ModelGateView`.
    func loadInitialState() {
        do {
            try refreshSnapshots()
            guard let user = currentUser else {
                modelGateStatus = .error("Curriculum profile could not be loaded.")
                return
            }
            modelGateStatus = .ready
            if appState == .gatingModel {
                appState = user.hasCompletedOnboarding ? .home : .onboarding
            }
        } catch {
            modelGateStatus = .error("Failed to load saved progress.")
        }
    }

    /// Routes a beginner directly to Phase 1 (`A1`) and marks onboarding completed.
    func startFromScratch() {
        guard let user = currentUser else { return }
        do {
            let outcome = try PlacementEvaluationUseCase.startFromScratch(user: user, phases: phases)
            try persistPlacementOutcome(outcome)
            try refreshSnapshots()
            errorMessage = nil
            appState = .home
        } catch {
            errorMessage = "Unable to start from Phase 1. Please try again."
        }
    }

    /// Prepares the 18 diagnostic placement questions ordered by phase (`A1` to `B2_ADV`).
    func beginPlacementTest() {
        let phaseOrderById = Dictionary(uniqueKeysWithValues: phases.map { ($0.id, $0.order) })
        let phaseIdBySkillId = Dictionary(uniqueKeysWithValues: skills.map { ($0.id, $0.phaseId) })
        placementQuestions = questions
            .filter(\.isPlacementEligible)
            .sorted { lhs, rhs in
                let lhsOrder = phaseOrderById[phaseIdBySkillId[lhs.skillId] ?? UUID()] ?? 0
                let rhsOrder = phaseOrderById[phaseIdBySkillId[rhs.skillId] ?? UUID()] ?? 0
                if lhsOrder != rhsOrder { return lhsOrder < rhsOrder }
                return lhs.id.uuidString < rhs.id.uuidString
            }
        errorMessage = nil
        appState = .placementTest
    }

    /// Evaluates the 18 placement submissions, saves the result to SwiftData, and stays on summary until continued.
    func completePlacementTest(submissions: [QuestionSubmission]) throws -> PlacementOutcome {
        guard let user = currentUser else {
            throw PlacementError.emptyPhases
        }
        let outcome = try PlacementEvaluationUseCase.evaluatePlacement(
            user: user,
            phases: phases,
            skills: skills,
            submissions: submissions
        )
        try persistPlacementOutcome(outcome)
        try refreshSnapshots()
        return outcome
    }

    func finishPlacementReview() {
        appState = .home
    }

    func openTest(for skill: Skill) {
        activeSkill = skill
        appState = .testInProgress
    }

    func returnHome() {
        activeSkill = nil
        activeAttempt = nil
        appState = .home
    }

    // MARK: - SwiftData Sync Helpers

    private func refreshSnapshots() throws {
        currentUser = try modelContext.fetch(FetchDescriptor<UserModel>()).first?.toDomain()
        phases = try modelContext.fetch(FetchDescriptor<PhaseModel>(sortBy: [SortDescriptor(\.order)]))
            .compactMap { $0.toDomain() }
        skills = try modelContext.fetch(FetchDescriptor<SkillModel>(sortBy: [SortDescriptor(\.skillCode)]))
            .map { $0.toDomain() }
        questions = try modelContext.fetch(FetchDescriptor<QuestionModel>())
            .compactMap { $0.toDomain() }
        attempts = try modelContext.fetch(FetchDescriptor<AttemptModel>(sortBy: [SortDescriptor(\.timestamp)]))
            .compactMap { $0.toDomain() }
    }

    private func persistPlacementOutcome(_ outcome: PlacementOutcome) throws {
        if let userModel = try modelContext.fetch(FetchDescriptor<UserModel>()).first {
            userModel.update(from: outcome.updatedUser)
        }
        let statusById = Dictionary(uniqueKeysWithValues: outcome.updatedPhases.map { ($0.id, $0.status.rawValue) })
        let phaseModels = try modelContext.fetch(FetchDescriptor<PhaseModel>())
        for model in phaseModels {
            if let status = statusById[model.id] {
                model.status = status
            }
        }
        if let attempt = outcome.attempt {
            modelContext.insert(AttemptModel(from: attempt))
        }
        try modelContext.save()
    }
}
