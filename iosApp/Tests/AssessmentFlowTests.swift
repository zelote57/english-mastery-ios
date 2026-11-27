import SwiftData
import XCTest
@testable import EnglishMastery

@MainActor
final class AssessmentFlowTests: XCTestCase {
    func testIncompletePlacementDoesNotStartOrPersist() throws {
        let container = try DataLayer.makeModelContainer(inMemory: true)
        try CurriculumSeeder.seedIfNeeded(in: container.mainContext)
        let coordinator = AppCoordinator(modelContext: container.mainContext)
        coordinator.loadInitialState()
        let id = try XCTUnwrap(coordinator.questions.first(where: \.isPlacementEligible)).id
        coordinator.questions.removeAll { $0.id == id }
        coordinator.beginPlacementTest()
        XCTAssertEqual(coordinator.appState, .onboarding)
        XCTAssertNotNil(coordinator.errorMessage)
        XCTAssertFalse(try XCTUnwrap(coordinator.currentUser).hasCompletedOnboarding)
        XCTAssertEqual(try container.mainContext.fetchCount(FetchDescriptor<AttemptModel>()), 0)
    }

    func testInvalidPlacementSubmissionsCannotPersist() throws {
        let container = try DataLayer.makeModelContainer(inMemory: true)
        try CurriculumSeeder.seedIfNeeded(in: container.mainContext)
        let coordinator = AppCoordinator(modelContext: container.mainContext)
        coordinator.loadInitialState()
        coordinator.beginPlacementTest()
        let first = try XCTUnwrap(coordinator.placementQuestions.first)
        let duplicate = Array(repeating: QuestionSubmission(question: first, userAnswer: first.correctAnswer), count: 18)
        XCTAssertThrowsError(try coordinator.completePlacementTest(submissions: duplicate))
        XCTAssertFalse(try XCTUnwrap(coordinator.currentUser).hasCompletedOnboarding)
        XCTAssertEqual(try container.mainContext.fetchCount(FetchDescriptor<AttemptModel>()), 0)
        let valid = coordinator.placementQuestions.map {
            QuestionSubmission(question: $0, userAnswer: $0.correctAnswer)
        }
        _ = try coordinator.completePlacementTest(submissions: valid)
        XCTAssertTrue(try XCTUnwrap(coordinator.currentUser).hasCompletedOnboarding)
        XCTAssertThrowsError(try coordinator.completePlacementTest(submissions: valid))
        XCTAssertEqual(try container.mainContext.fetchCount(FetchDescriptor<AttemptModel>()), 1)
    }

    func testAssessmentPersistsFeedbackAndDrillDoesNotChangeProgress() throws {
        let container = try DataLayer.makeModelContainer(inMemory: true)
        try CurriculumSeeder.seedIfNeeded(in: container.mainContext)
        let coordinator = AppCoordinator(modelContext: container.mainContext)
        coordinator.loadInitialState()
        coordinator.startFromScratch()
        let user = try XCTUnwrap(coordinator.currentUser)
        let skill = try XCTUnwrap(coordinator.skills.first { $0.phaseId == user.currentPhaseId })
        let bank = (0..<16).map { index in
            Question(skillId: skill.id, prompt: "Question \(index)", correctAnswer: "correct",
                     distractors: ["wrong"], questionType: .multipleChoice)
        }
        coordinator.questions = bank
        coordinator.openTest(for: skill)
        let viewModel = TestViewModel(skill: skill, questions: bank, attempts: [])
        XCTAssertEqual(viewModel.questions.count, 15)
        XCTAssertEqual(Set(viewModel.questions.map(\.id)).count, 15)

        viewModel.inputController.selectedChoice = "wrong"
        viewModel.submit { try coordinator.completeSkillTest(submissions: $0) }
        XCTAssertTrue(viewModel.showingFeedback)
        XCTAssertEqual(viewModel.currentIndex, 0)
        XCTAssertTrue(viewModel.feedback.contains("### 📘 Regla clave"))
        viewModel.advance { try coordinator.completeSkillTest(submissions: $0) }
        for _ in 1..<15 {
            viewModel.inputController.selectedChoice = "correct"
            viewModel.submit { try coordinator.completeSkillTest(submissions: $0) }
        }
        XCTAssertEqual(coordinator.appState, .reviewingFeedback)
        let attempt = try XCTUnwrap(coordinator.activeAttempt)
        XCTAssertEqual(attempt.score, 14.0 / 15.0, accuracy: 0.0001)
        XCTAssertNotNil(attempt.answers.first { $0.pointsEarned == 0 }?.ragFeedback)
        XCTAssertEqual(coordinator.activeSkill?.isPassed, true)

        let context = ModelContext(container)
        let saved = try XCTUnwrap(context.fetch(FetchDescriptor<AttemptModel>()).first?.toDomain())
        XCTAssertEqual(saved.answers.count, 15)
        XCTAssertNotNil(saved.answers.first { $0.pointsEarned == 0 }?.ragFeedback)
        let beforeUser = try XCTUnwrap(coordinator.currentUser)
        let beforeSkill = try XCTUnwrap(coordinator.activeSkill)
        let drill = MistakeDrillViewModel(attempt: attempt, questions: bank)
        drill.inputController.selectedChoice = "wrong"
        drill.submit()
        XCTAssertEqual(drill.drill.completedCount, 0)
        drill.continueDrill()
        drill.inputController.selectedChoice = "correct"
        drill.submit()
        XCTAssertTrue(drill.drill.isCompleted)
        XCTAssertEqual(coordinator.currentUser, beforeUser)
        XCTAssertEqual(coordinator.activeSkill, beforeSkill)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<AttemptModel>()), 1)
    }

    func testTypoShowsFeedbackAndSaveFailureCanBeRetried() throws {
        let skill = Skill(skillCode: "A1-01", topic: "Pronouns", phaseId: UUID())
        let bank = (0..<15).map { index in
            Question(skillId: skill.id, prompt: "Question \(index)", correctAnswer: "worked", questionType: .fillBlank)
        }
        let viewModel = TestViewModel(skill: skill, questions: bank, attempts: [])
        viewModel.inputController.textAnswer = "workd"
        viewModel.submit { _ in XCTFail("Should not finish yet") }
        XCTAssertTrue(viewModel.showingFeedback)
        XCTAssertEqual(viewModel.submissions.first?.userAnswer, "workd")
        XCTAssertNotNil(viewModel.submissions.first?.ragFeedback)
        XCTAssertEqual(viewModel.currentIndex, 0)
        viewModel.advance { _ in XCTFail("Should not finish yet") }
        for _ in 1..<14 {
            viewModel.inputController.textAnswer = "worked"
            viewModel.submit { _ in XCTFail("Should not finish yet") }
        }
        viewModel.inputController.textAnswer = "worked"
        viewModel.submit { _ in throw AppCoordinator.AssessmentError.missingProgress }
        XCTAssertNotNil(viewModel.errorMessage)
        XCTAssertEqual(viewModel.submissions.count, 15)
        var savedCount = 0
        viewModel.advance { submissions in savedCount = submissions.count }
        XCTAssertEqual(savedCount, 15)
        XCTAssertNil(viewModel.errorMessage)
    }

    func testShortQuestionBankCannotStartAssessment() {
        let skill = Skill(skillCode: "A1-01", topic: "Pronouns", phaseId: UUID())
        let viewModel = TestViewModel(skill: skill, questions: [], attempts: [])
        XCTAssertNotNil(viewModel.errorMessage)
        XCTAssertNil(viewModel.currentQuestion)
    }

    func testPreviouslyMissedAndUnseenQuestionsArePrioritized() {
        let skill = Skill(skillCode: "A1-01", topic: "Pronouns", phaseId: UUID())
        let bank = (0..<16).map { index in
            Question(skillId: skill.id, prompt: "\(index)", correctAnswer: "yes", questionType: .multipleChoice)
        }
        let attemptId = UUID()
        let answers = bank.prefix(15).enumerated().map { index, question in
            AnswerRecord(attemptId: attemptId, questionId: question.id, userAnswer: "yes",
                         pointsEarned: index == 0 ? 0 : 1)
        }
        let attempt = Attempt(id: attemptId, userId: UUID(), skillId: skill.id, score: 0.9,
                              earnedPoints: 14, totalQuestions: 15, correctAnswers: 14, answers: answers)
        let viewModel = TestViewModel(skill: skill, questions: bank, attempts: [attempt])
        let selected = Set(viewModel.questions.map(\.id))
        XCTAssertTrue(selected.contains(bank[0].id))
        XCTAssertTrue(selected.contains(bank[15].id))
    }
}
