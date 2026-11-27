import SwiftUI

struct PhaseHeaderView<Content: View>: View {
    let phase: Phase
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Text(phase.level.rawValue)
                    .font(.caption)
                    .fontWeight(.bold)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(phaseColor.opacity(0.15))
                    .foregroundStyle(phaseColor)
                    .clipShape(Capsule())
                VStack(alignment: .leading, spacing: 2) {
                    Text(phase.title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Text(phase.cambridgeAlignment)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                phaseStatusIcon
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(.systemGroupedBackground))

            content()
        }
    }

    private var phaseColor: Color {
        switch phase.status {
        case .completed: .green
        case .skippedPassed: .teal
        case .available: .blue
        case .locked: .gray
        }
    }

    private var phaseStatusIcon: some View {
        switch phase.status {
        case .completed:
            Image(systemName: "checkmark.seal.fill").foregroundStyle(.green)
        case .skippedPassed:
            Image(systemName: "forward.fill").foregroundStyle(.teal)
        case .available:
            Image(systemName: "circle.fill").foregroundStyle(.blue)
        case .locked:
            Image(systemName: "lock.fill").foregroundStyle(.gray)
        }
    }
}
