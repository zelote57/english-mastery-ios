import SwiftUI

/// Displays the assigned Cambridge starting phase after the 18-question placement test.
struct PlacementSummaryView: View {
    let outcome: PlacementOutcome
    let onContinue: () -> Void

    private var skippedCount: Int {
        outcome.updatedPhases.count { $0.status == .skippedPassed }
    }

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            summaryBadge
            Spacer()
            Button("Continue", action: onContinue)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .padding(24)
        .background(Color(.systemBackground))
    }

    private var summaryBadge: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 56))
                .foregroundStyle(.blue)
                .accessibilityHidden(true)
            Text("Placement Complete")
                .font(.largeTitle.bold())
            Text("Starting at Phase \(outcome.targetPhase.order): \(outcome.targetPhase.title)")
                .font(.headline)
                .multilineTextAlignment(.center)
            Text(outcome.targetPhase.cambridgeAlignment)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            if skippedCount > 0 {
                Text("\(skippedCount) earlier phase(s) unlocked for optional review.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.top, 4)
            }
        }
    }
}
