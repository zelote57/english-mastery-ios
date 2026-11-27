import XCTest
@testable import EnglishMastery

final class ScoringEngineTests: XCTestCase {
    private let skillId = UUID()

    private func makeQuestion(
        type: QuestionType,
        correctAnswer: String,
        acceptedSynonyms: [String] = []
    ) -> Question {
        Question(
            skillId: skillId,
            prompt: "Test prompt",
            correctAnswer: correctAnswer,
            acceptedSynonyms: acceptedSynonyms,
            distractors: ["wrong1", "wrong2"],
            questionType: type
        )
    }

    func testExactMatchWithWhitespaceCaseApostropheAndTerminalPunctuation() {
        let question = makeQuestion(type: .translation, correctAnswer: "She didn't go home.")
        let result = ScoringEngine.grade(answer: "  SHE   didn\u{2019}t  go home?!  ", for: question)
        XCTAssertEqual(result.pointsEarned, 1.0)
        XCTAssertTrue(result.isCorrect)
    }

    func testAcceptedSynonymAwardsFullCreditAndContractionsAreNotGloballyExpanded() {
        let withSynonym = makeQuestion(
            type: .translation,
            correctAnswer: "I'm happy",
            acceptedSynonyms: ["I am happy"]
        )
        XCTAssertEqual(ScoringEngine.grade(answer: "I am happy.", for: withSynonym).pointsEarned, 1.0)

        let strictContraction = makeQuestion(type: .fillBlank, correctAnswer: "I'm")
        XCTAssertEqual(ScoringEngine.grade(answer: "I am", for: strictContraction).pointsEarned, 0.0)
    }

    func testSpellingAndGrammarMistakesReceiveNoCredit() {
        let short = makeQuestion(type: .fillBlank, correctAnswer: "she")
        let question = makeQuestion(
            type: .translation,
            correctAnswer: "worked",
            acceptedSynonyms: ["studied"]
        )
        XCTAssertEqual(ScoringEngine.grade(answer: "he", for: short).pointsEarned, 0.0)
        XCTAssertEqual(ScoringEngine.grade(answer: "sge", for: short).pointsEarned, 0.0)
        XCTAssertEqual(ScoringEngine.grade(answer: "workd", for: question).pointsEarned, 0.0)
        XCTAssertEqual(ScoringEngine.grade(answer: "studid", for: question).pointsEarned, 0.0)
    }

    func testEmptyAndPunctuationOnlyInputsNeverEarnCredit() {
        let singleCharTarget = makeQuestion(type: .fillBlank, correctAnswer: "a")
        XCTAssertEqual(ScoringEngine.grade(answer: "", for: singleCharTarget).pointsEarned, 0.0)
        XCTAssertEqual(ScoringEngine.grade(answer: "   ...?! ", for: singleCharTarget).pointsEarned, 0.0)
    }

    func testMultipleChoiceAndReorderAreStrictlyBinary() {
        let mc = makeQuestion(type: .multipleChoice, correctAnswer: "worked")
        XCTAssertEqual(ScoringEngine.grade(answer: "workd", for: mc).pointsEarned, 0.0)
        XCTAssertEqual(ScoringEngine.grade(answer: "worked.", for: mc).pointsEarned, 1.0)

        let reorder = makeQuestion(type: .reorder, correctAnswer: "She studies English")
        XCTAssertEqual(ScoringEngine.grade(answer: "She study English", for: reorder).pointsEarned, 0.0)
        XCTAssertEqual(ScoringEngine.grade(answer: " she  studies English! ", for: reorder).pointsEarned, 1.0)
    }

    func testBuildAttemptCountsOnlyFullAnswersInCorrectAnswersAndFiltersRagFeedback() {
        let fullQ = makeQuestion(type: .multipleChoice, correctAnswer: "is")
        let typoQ = makeQuestion(type: .fillBlank, correctAnswer: "worked")
        let failQ = makeQuestion(type: .fillBlank, correctAnswer: "went")

        var submissions: [QuestionSubmission] = Array(
            repeating: QuestionSubmission(question: fullQ, userAnswer: "is", ragFeedback: "should-be-cleared"),
            count: 12
        )
        submissions += Array(
            repeating: QuestionSubmission(question: typoQ, userAnswer: "workd", ragFeedback: "typo-feedback"),
            count: 1
        )
        submissions += Array(
            repeating: QuestionSubmission(question: failQ, userAnswer: "goed", ragFeedback: "### 💡 Explicación"),
            count: 2
        )

        let attempt = ScoringEngine.buildAttempt(
            from: submissions,
            userId: UUID(),
            skillId: skillId,
            attemptType: .skillAssessment
        )

        XCTAssertEqual(attempt.totalQuestions, 15)
        XCTAssertEqual(attempt.correctAnswers, 12)
        XCTAssertEqual(attempt.earnedPoints, 12.0, accuracy: 0.0001)
        XCTAssertEqual(attempt.score, 0.80, accuracy: 0.0001)
        XCTAssertNil(attempt.answers.first?.ragFeedback)
        XCTAssertEqual(attempt.answers[12].pointsEarned, 0)
        XCTAssertEqual(attempt.answers[12].ragFeedback, "typo-feedback")
        XCTAssertEqual(attempt.answers.last?.ragFeedback, "### 💡 Explicación")
    }
}
