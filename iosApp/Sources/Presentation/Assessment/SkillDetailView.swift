import SwiftUI
import Charts

struct SkillDetailView: View {
    let coordinator: AppCoordinator
    let skill: Skill

    private var attempts: [Attempt] {
        coordinator.attempts.filter { $0.skillId == skill.id && $0.attemptType == .skillAssessment }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text(skill.topic).font(.title2.bold())
                    LabeledContent("Best score", value: "\(Int(skill.bestScore * 100))%")
                    LabeledContent("Official attempts", value: "\(attempts.count)")
                }
                Section("Last 5 attempts") {
                    let recent = Attempt.recentSkillAttempts(for: skill.id, in: attempts)
                    if recent.isEmpty {
                        Text("No attempts yet").foregroundStyle(.secondary)
                    } else {
                        Chart(recent) { attempt in
                            LineMark(x: .value("Date", attempt.timestamp), y: .value("Score", attempt.score))
                            PointMark(x: .value("Date", attempt.timestamp), y: .value("Score", attempt.score))
                        }
                        .chartYScale(domain: 0...1)
                        .frame(height: 160)
                        ForEach(recent) { attempt in
                            LabeledContent {
                                Text("\(Int(attempt.score * 100))%")
                            } label: {
                                Text(attempt.timestamp, style: .date)
                            }
                        }
                    }
                }
                Button("Start Test") { coordinator.openTest(for: skill) }
                    .buttonStyle(.borderedProminent)
            }
            .navigationTitle(skill.skillCode)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Back to Home") { coordinator.returnHome() }
                }
            }
        }
    }
}
