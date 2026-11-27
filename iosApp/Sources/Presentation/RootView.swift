import SwiftUI

struct RootView: View {
    let coordinator: AppCoordinator

    var body: some View {
        switch coordinator.appState {
        case .gatingModel:
            ModelGateView(coordinator: coordinator)
        case .onboarding:
            OnboardingView(coordinator: coordinator)
        case .placementTest:
            PlacementTestView(coordinator: coordinator, questions: coordinator.placementQuestions)
        case .home:
            HomeView(coordinator: coordinator)
        case .skillDetail:
            if let skill = coordinator.activeSkill {
                SkillDetailView(coordinator: coordinator, skill: skill)
            }
        case .testInProgress:
            if let skill = coordinator.activeSkill {
                TestView(coordinator: coordinator, skill: skill)
            }
        case .reviewingFeedback:
            if let attempt = coordinator.activeAttempt, let skill = coordinator.activeSkill {
                FeedbackView(coordinator: coordinator, skill: skill, attempt: attempt)
            }
        case .mistakeDrill:
            if let attempt = coordinator.activeAttempt {
                MistakeDrillView(coordinator: coordinator, attempt: attempt)
            }
        }
    }
}
