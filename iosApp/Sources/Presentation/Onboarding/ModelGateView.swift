import SwiftUI

/// Milestone 2 placeholder gate before routing to `OnboardingView` or `HomeView`.
struct ModelGateView: View {
    let coordinator: AppCoordinator

    var body: some View {
        VStack(spacing: 20) {
            switch coordinator.modelGateStatus {
            case .loading:
                ProgressView("Preparing offline curriculum...")
            case .downloading(let progress):
                VStack(spacing: 12) {
                    ProgressView("Downloading AI tutor...", value: progress, total: 1.0)
                    Text("\(Int(progress * 100))%")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 32)
            case .ready:
                ProgressView("Loading your learning path...")
            case .error(let message):
                ContentUnavailableView {
                    Label("Unable to Load Curriculum", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(message)
                } actions: {
                    Button("Retry") {
                        coordinator.loadInitialState()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
        .task {
            coordinator.loadInitialState()
        }
    }
}
