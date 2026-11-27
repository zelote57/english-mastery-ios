import SwiftUI

struct FeedbackView: View {
    let coordinator: AppCoordinator
    let skill: Skill
    let attempt: Attempt

    private var missed: [AnswerRecord] {
        attempt.answers.filter { $0.pointsEarned == 0 }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    if attempt.score >= 0.80 {
                        CelebrationView()
                    }

                    private struct CelebrationView: View {
                        @State private var animate = false

                        var body: some View {
                            HStack {
                                Image(systemName: "party.popper.fill")
                                    .rotationEffect(.degrees(animate ? 15 : -15))
                                    .scaleEffect(animate ? 1.2 : 1)
                                Text("Great work!")
                                Image(systemName: "sparkles")
                                    .scaleEffect(animate ? 1.2 : 0.8)
                            }
                            .font(.title2.bold())
                            .foregroundStyle(.green)
                            .onAppear {
                                withAnimation(.easeInOut(duration: 0.6).repeatCount(3, autoreverses: true)) {
                                    animate = true
                                }
                            }
                        }
                    }
                    LabeledContent("Score", value: "\(Int(attempt.score * 100))%")
                    LabeledContent("Points", value: "\(attempt.earnedPoints.formatted()) / \(attempt.totalQuestions)")
                }
                if !missed.isEmpty {
                    Section("Missed Questions") {
                        ForEach(missed) { answer in
                            DisclosureGroup(
                                coordinator.questions.first { $0.id == answer.questionId }?.prompt ?? "Question"
                            ) {
                                if let feedback = answer.ragFeedback {
                                    Text(LocalizedStringKey(feedback))
                                }
                            }
                        }
                    }
                    Button("Practice Missed Questions") { coordinator.appState = .mistakeDrill }
                }
                Section {
                    Button("Retry Test") { coordinator.openTest(for: skill) }
                    if let next = coordinator.nextSkill {
                        Button("Next Skill") { coordinator.openSkill(next) }
                    }
                    Button("Back to Home") { coordinator.returnHome() }
                }
            }
            .navigationTitle("Results")
        }
    }
}
