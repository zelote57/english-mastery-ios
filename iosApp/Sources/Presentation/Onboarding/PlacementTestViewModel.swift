import Foundation
import Observation

/// Coordinates the 18-question diagnostic placement flow without mid-test RAG sheets.
@Observable
@MainActor
final class PlacementTestViewModel {
    let questions: [Question]
    let shuffleOptions: Bool
    let inputController = QuestionInputController()

    private(set) var currentIndex: Int = 0
    private(set) var submissions: [QuestionSubmission] = []
    private(set) var completionOutcome: PlacementOutcome?
    var submissionError: String?

    init(questions: [Question], shuffleOptions: Bool = true) {
        self.questions = questions
        self.shuffleOptions = shuffleOptions
        if let first = questions.first {
            inputController.load(question: first, shuffleOptions: shuffleOptions)
        }
    }

    var currentQuestion: Question? {
        guard questions.indices.contains(currentIndex) else { return nil }
        return questions[currentIndex]
    }

    var isLastQuestion: Bool {
        currentIndex + 1 >= questions.count
    }

    var progressFraction: Double {
        guard !questions.isEmpty else { return 0.0 }
        return Double(currentIndex + 1) / Double(questions.count)
    }

    func submitCurrentAnswer(
        onComplete: ([QuestionSubmission]) throws -> PlacementOutcome
    ) {
        guard completionOutcome == nil,
              let question = currentQuestion,
              inputController.canSubmit else {
            return
        }

        let submission = QuestionSubmission(
            question: question,
            userAnswer: inputController.currentAnswerString,
            ragFeedback: nil
        )
        if submissions.count == currentIndex {
            submissions.append(submission)
        } else {
            submissions[currentIndex] = submission
        }

        if currentIndex + 1 < questions.count {
            currentIndex += 1
            inputController.load(question: questions[currentIndex], shuffleOptions: shuffleOptions)
            submissionError = nil
        } else {
            do {
                completionOutcome = try onComplete(submissions)
                submissionError = nil
            } catch {
                submissionError = "Unable to save placement results. Please try again."
            }
        }
    }
}
