import SwiftUI

struct TestView: View {
    let coordinator: AppCoordinator
    @State private var viewModel: TestViewModel

    init(coordinator: AppCoordinator, skill: Skill) {
        self.coordinator = coordinator
        _viewModel = State(initialValue: TestViewModel(
            skill: skill, questions: coordinator.questions, attempts: coordinator.attempts
        ))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                if viewModel.questions.count == 15, let question = viewModel.currentQuestion {
                    Text("Question \(viewModel.currentIndex + 1) of 15")
                    ProgressView(value: Double(viewModel.currentIndex + 1), total: 15)
                    ScrollView {
                        QuestionInputView(question: question, controller: viewModel.inputController, onSubmit: submit)
                    }
                    if viewModel.submissions.count > viewModel.currentIndex {
                        Button("Try Again", action: advance).buttonStyle(.borderedProminent)
                    } else {
                        Button("Submit", action: submit)
                            .buttonStyle(.borderedProminent)
                            .disabled(!viewModel.inputController.canSubmit)
                    }
                }
                if let error = viewModel.errorMessage {
                    Text(error).foregroundStyle(.red)
                }
            }
            .padding(20)
            .navigationTitle("Skill Test")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { coordinator.returnHome() }
                }
            }
            .sheet(isPresented: $viewModel.showingFeedback) {
                NavigationStack {
                    ScrollView {
                        Text(LocalizedStringKey(viewModel.feedback))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                    }
                    .navigationTitle("Feedback")
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Continue", action: advance)
                        }
                    }
                }
                .interactiveDismissDisabled()
            }
        }
    }

    private func submit() {
        viewModel.submit { try coordinator.completeSkillTest(submissions: $0) }
    }

    private func advance() {
        viewModel.advance { try coordinator.completeSkillTest(submissions: $0) }
    }
}
