import SwiftUI

struct MistakeDrillView: View {
    let coordinator: AppCoordinator
    @State private var viewModel: MistakeDrillViewModel

    init(coordinator: AppCoordinator, attempt: Attempt) {
        self.coordinator = coordinator
        _viewModel = State(initialValue: MistakeDrillViewModel(attempt: attempt, questions: coordinator.questions))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                if let result = viewModel.resultMessage {
                    Text(result)
                    Button("Continue") { viewModel.continueDrill() }.buttonStyle(.borderedProminent)
                } else if let question = viewModel.drill.currentQuestion {
                    Text("\(viewModel.drill.completedCount) of \(viewModel.drill.totalMissedCount) completed")
                    ScrollView {
                        QuestionInputView(question: question, controller: viewModel.inputController) {
                            viewModel.submit()
                        }
                    }
                    Button("Submit") { viewModel.submit() }
                        .buttonStyle(.borderedProminent)
                        .disabled(!viewModel.inputController.canSubmit)
                } else {
                    Text("Practice complete!").font(.title2.bold())
                    Button("Back to Results") { coordinator.appState = .reviewingFeedback }
                        .buttonStyle(.borderedProminent)
                }
            }
            .padding(20)
            .navigationTitle("Practice Missed Questions")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Back to Results") { coordinator.appState = .reviewingFeedback }
                }
            }
        }
    }
}
