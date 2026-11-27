import SwiftUI

/// Diagnostic 18-question placement flow (`2` per phase, no mid-test RAG interruptions).
struct PlacementTestView: View {
    let coordinator: AppCoordinator
    @State private var viewModel: PlacementTestViewModel

    init(coordinator: AppCoordinator, questions: [Question]) {
        self.coordinator = coordinator
        self._viewModel = State(initialValue: PlacementTestViewModel(questions: questions))
    }

    var body: some View {
        NavigationStack {
            Group {
                if let outcome = viewModel.completionOutcome {
                    PlacementSummaryView(outcome: outcome) {
                        coordinator.finishPlacementReview()
                    }
                } else {
                    PlacementQuestionBody(viewModel: viewModel) {
                        submitCurrent()
                    }
                }
            }
            .navigationTitle("Placement Test")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if viewModel.completionOutcome == nil {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { coordinator.appState = .onboarding }
                    }
                }
            }
        }
    }

    private func submitCurrent() {
        viewModel.submitCurrentAnswer { submissions in
            try coordinator.completePlacementTest(submissions: submissions)
        }
    }
}

private struct PlacementQuestionBody: View {
    let viewModel: PlacementTestViewModel
    let onSubmit: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            progressHeader
            ScrollView {
                if let question = viewModel.currentQuestion {
                    QuestionInputView(
                        question: question,
                        controller: viewModel.inputController,
                        onSubmit: onSubmit
                    )
                    .padding(.vertical, 8)
                }
            }
            if let error = viewModel.submissionError {
                Text(error).font(.footnote).foregroundStyle(.red)
            }
            Button(viewModel.isLastQuestion ? "Finish Placement Test" : "Next", action: onSubmit)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .frame(maxWidth: .infinity, minHeight: 44)
                .disabled(!viewModel.inputController.canSubmit)
        }
        .padding(20)
        .background(Color(.systemBackground))
        .sensoryFeedback(.selection, trigger: viewModel.currentIndex)
    }

    private var progressHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Question \(viewModel.currentIndex + 1) of \(viewModel.questions.count)")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            ProgressView(value: viewModel.progressFraction)
                .tint(.blue)
        }
    }
}
