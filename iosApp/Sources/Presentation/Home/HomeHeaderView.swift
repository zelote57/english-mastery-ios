import SwiftUI

struct HomeHeaderView: View {
    let userName: String
    let streakDays: Int
    let progressFraction: Double
    let activePhase: Phase?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Hello, \(userName)!")
                    .font(.title2)
                    .fontWeight(.semibold)
                Spacer()
                if streakDays > 0 {
                    Label("\(streakDays)", systemImage: "flame.fill")
                        .foregroundStyle(.orange)
                        .fontWeight(.semibold)
                        .accessibilityLabel("\(streakDays) day streak")
                }
            }
            if let activePhase {
                Text("Phase \(activePhase.title) — \(activePhase.cambridgeAlignment)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            ProgressView(value: progressFraction)
                .tint(.blue)
                .accessibilityLabel("Overall progress: \(Int(progressFraction * 100))%")
            Text("\(Int(progressFraction * 100))% complete")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
