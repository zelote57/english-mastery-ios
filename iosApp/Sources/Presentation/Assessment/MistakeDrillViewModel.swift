import Foundation
import Observation

@Observable
@MainActor
final class MistakeDrillViewModel {
    private(set) var drill: MistakeDrillUseCase
    let inputController = QuestionInputController()
    private(set) var resultMessage: String?

    init(attempt: Attempt, questions: [Question]) {
        drill = MistakeDrillUseCase(attempt: attempt, questions: questions)
        if let question = drill.currentQuestion {
            inputController.load(question: question)
        }
    }

    func submit() {
        guard resultMessage == nil, inputController.canSubmit, let question = drill.currentQuestion else { return }
        let correct = drill.submit(answer: inputController.currentAnswerString)
        resultMessage = correct ? "Correct!" : "Try again. The correct answer is: \(question.correctAnswer)"
    }

    func continueDrill() {
        resultMessage = nil
        if let question = drill.currentQuestion {
            inputController.load(question: question)
        }
    }
}
