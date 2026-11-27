import SwiftUI

/// Top-level view driven by `AppCoordinator.appState`. Part 2 cases show a placeholder until implemented.
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
        case .testInProgress, .reviewingFeedback, .mistakeDrill:
            // Part 2 — implemented in Milestone 2 Part 2
            ProgressView("Coming soon…")
        }
    }
}
