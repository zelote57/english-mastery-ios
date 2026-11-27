import SwiftUI

/// Initial learner path selection (`Start from Scratch` vs `Take Placement Test`).
struct OnboardingView: View {
    let coordinator: AppCoordinator

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            headerSection
            Spacer()
            if let error = coordinator.errorMessage {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }
            actionButtons
        }
        .padding(24)
        .background(Color(.systemBackground))
    }

    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "graduationcap.fill")
                .font(.system(size: 56))
                .foregroundStyle(.blue)
                .accessibilityHidden(true)
            Text("English Mastery")
                .font(.largeTitle.bold())
            Text("Master Cambridge English from A1 Foundation to B2 Advanced across 9 sequential phases.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    private var actionButtons: some View {
        VStack(spacing: 12) {
            Button {
                coordinator.beginPlacementTest()
            } label: {
                VStack(spacing: 4) {
                    Text("Take Placement Test")
                        .font(.headline)
                    Text("18 diagnostic questions to find your starting phase")
                        .font(.caption)
                }
                .frame(maxWidth: .infinity, minHeight: 52)
            }
            .buttonStyle(.borderedProminent)

            Button {
                coordinator.startFromScratch()
            } label: {
                VStack(spacing: 4) {
                    Text("Start from Scratch")
                        .font(.headline)
                    Text("Begin at Phase 1 (A1 Foundation)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 52)
            }
            .buttonStyle(.bordered)
        }
    }
}
