import Foundation
import Observation

/// Unique token representing a draggable/tappable word in `.reorder` questions.
struct ReorderToken: Identifiable, Equatable, Sendable {
    let id: Int
    let text: String
}

/// Manages single-shuffle option layout and learner input across all four `QuestionType` modes.
/// Shuffling occurs strictly when `load(question:)` is called, never inside SwiftUI `View.body`.
@Observable
@MainActor
final class QuestionInputController {
    private(set) var question: Question?
    private(set) var multipleChoiceOptions: [String] = []
    private(set) var availableTokens: [ReorderToken] = []
    var selectedTokens: [ReorderToken] = []
    var selectedChoice: String?
    var textAnswer: String = ""

    var currentAnswerString: String {
        guard let question else { return "" }
        switch question.questionType {
        case .multipleChoice:
            return selectedChoice ?? ""
        case .fillBlank, .translation:
            return textAnswer
        case .reorder:
            return selectedTokens.map(\.text).joined(separator: " ")
        }
    }

    var canSubmit: Bool {
        !currentAnswerString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var displayPrompt: String {
        guard let question else { return "" }
        if question.questionType == .reorder,
           question.prompt.hasPrefix("Reorder the words:") {
            return "Tap the words in the correct order:"
        }
        return question.prompt
    }

    func load(question: Question, shuffleOptions: Bool = true) {
        self.question = question
        selectedTokens = []
        selectedChoice = nil
        textAnswer = ""

        switch question.questionType {
        case .multipleChoice:
            let options = [question.correctAnswer] + question.distractors
            multipleChoiceOptions = shuffleOptions ? options.shuffled() : options
            availableTokens = []
        case .reorder:
            multipleChoiceOptions = []
            let rawTokens = Self.parseReorderTokens(from: question, shuffleFallback: shuffleOptions)
            availableTokens = rawTokens.enumerated().map { ReorderToken(id: $0.offset, text: $0.element) }
        case .fillBlank, .translation:
            multipleChoiceOptions = []
            availableTokens = []
        }
    }

    func selectToken(_ token: ReorderToken) {
        guard !selectedTokens.contains(token) else { return }
        selectedTokens.append(token)
    }

    func removeSelectedToken(_ token: ReorderToken) {
        selectedTokens.removeAll { $0.id == token.id }
    }

    func clearReorderSelection() {
        selectedTokens.removeAll()
    }

    private static func parseReorderTokens(from question: Question, shuffleFallback: Bool) -> [String] {
        if let colonIndex = question.prompt.firstIndex(of: ":") {
            let suffix = question.prompt[question.prompt.index(after: colonIndex)...]
            let parsed = suffix
                .components(separatedBy: "/")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            if !parsed.isEmpty {
                return parsed
            }
        }
        let words = question.correctAnswer.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        return shuffleFallback ? words.shuffled() : words
    }
}
