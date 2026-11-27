import SwiftUI

struct SkillRowView: View {
    let skill: Skill
    let state: SkillDisplayState
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                stateIcon
                    .frame(width: 28, height: 28)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(skill.skillCode)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                    Text(skill.topic)
                        .font(.subheadline)
                        .foregroundStyle(state == .locked ? .secondary : .primary)
                        .multilineTextAlignment(.leading)
                }
                Spacer()
                if skill.bestScore > 0 {
                    Text("\(Int(skill.bestScore * 100))%")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(skill.isPassed ? .green : .secondary)
                        .accessibilityLabel("Best score \(Int(skill.bestScore * 100)) percent")
                }
                if state != .locked {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(state == .locked)
        .background(Color(.systemBackground))
        .overlay(alignment: .bottom) {
            Divider().padding(.leading, 56)
        }
        .accessibilityLabel(accessibilityLabel)
    }

    private var stateIcon: some View {
        switch state {
        case .passed:
            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green).font(.title3)
        case .skippedPassed:
            Image(systemName: "forward.circle.fill").foregroundStyle(.teal).font(.title3)
        case .available:
            Image(systemName: "circle").foregroundStyle(.blue).font(.title3)
        case .locked:
            Image(systemName: "lock.circle.fill").foregroundStyle(.gray).font(.title3)
        }
    }

    private var accessibilityLabel: String {
        let stateText: String
        switch state {
        case .passed: stateText = "Passed"
        case .skippedPassed: stateText = "Skipped passed"
        case .available: stateText = "Available"
        case .locked: stateText = "Locked"
        }
        let scoreText = skill.bestScore > 0 ? ", best score \(Int(skill.bestScore * 100))%" : ""
        return "\(skill.topic)\(scoreText), \(stateText)"
    }
}
