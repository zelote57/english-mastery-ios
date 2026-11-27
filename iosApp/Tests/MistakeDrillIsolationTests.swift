import XCTest
@testable import EnglishMastery

final class MistakeDrillIsolationTests: XCTestCase {
    func testDrillQueuesOnlyZeroPointQuestionsLoopsUntilExactAndNeverMutatesOfficialMetrics() {
        let phase = Phase(level: .a1, title: "A1", cambridgeAlignment: "Pre-A2", status: .available)
        let skill = Skill(skillCode: "A1-05", topic: "Simple present", phaseId: phase.id)
        let user = User(currentPhaseId: phase.id, hasCompletedOnboarding: true)

        let qPass = Question(skillId: skill.id, prompt: "Q1", correctAnswer: "works", questionType: .fillBlank)
        let qPartial = Question(skillId: skill.id, prompt: "Q2", correctAnswer: "studies", questionType: .fillBlank)
        let qFail1 = Question(skillId: skill.id, prompt: "Q3", correctAnswer: "watches", questionType: .fillBlank)
        let qFail2 = Question(skillId: skill.id, prompt: "Q4", correctAnswer: "goes", questionType: .fillBlank)

        let submissions = Array(repeating: QuestionSubmission(question: qPass, userAnswer: "works"), count: 8)
            + [QuestionSubmission(question: qPartial, userAnswer: "studis")] // +0.5 partial (NOT queued for drill)
            + [
                QuestionSubmission(question: qFail1, userAnswer: "watching", ragFeedback: "Explicación 1"), // 3 edits > 2 -> 0.0 miss
                QuestionSubmission(question: qFail2, userAnswer: "go", ragFeedback: "Explicación 2")        // 2 edits > 1 -> 0.0 miss
            ]

        let evaluation = EvaluateAttemptUseCase.evaluate(
            user: user,
            skill: skill,
            phases: [phase],
            skills: [skill],
            submissions: submissions
        )

        let recordedAttemptsSnapshot = [evaluation.attempt]
        let userSnapshot = evaluation.updatedUser
        let skillSnapshot = evaluation.updatedSkill
        let phasesSnapshot = evaluation.updatedPhases

        var drill = MistakeDrillUseCase(
            attempt: evaluation.attempt,
            questions: [qPass, qPartial, qFail1, qFail2]
        )

        XCTAssertEqual(drill.totalMissedCount, 2)
        XCTAssertEqual(drill.currentQuestion?.id, qFail1.id)

        // Wrong answer rotates qFail1 after qFail2
        XCTAssertFalse(drill.submit(answer: "watching"))
        XCTAssertEqual(drill.currentQuestion?.id, qFail2.id)
        XCTAssertFalse(drill.isCompleted)

        // Exact answer clears qFail2
        XCTAssertTrue(drill.submit(answer: "goes"))
        XCTAssertEqual(drill.currentQuestion?.id, qFail1.id)
        XCTAssertEqual(drill.completedCount, 1)

        // Partial (+0.5) spelling slip during drill requires full exact retry
        XCTAssertFalse(drill.submit(answer: "watces"))
        XCTAssertFalse(drill.isCompleted)

        // Exact answer completes drill
        XCTAssertTrue(drill.submit(answer: "watches"))
        XCTAssertTrue(drill.isCompleted)
        XCTAssertEqual(drill.completedCount, 2)
        XCTAssertNil(drill.currentQuestion)

        // Strict Drill Score Isolation invariants remain untouched
        XCTAssertEqual(recordedAttemptsSnapshot.count, 1)
        XCTAssertEqual(recordedAttemptsSnapshot[0].score, evaluation.attempt.score)
        XCTAssertEqual(skillSnapshot.bestScore, evaluation.attempt.score)
        XCTAssertFalse(skillSnapshot.isPassed)
        XCTAssertEqual(userSnapshot.currentPhaseId, phase.id)
        XCTAssertEqual(userSnapshot.streakDays, 1)
        XCTAssertEqual(phasesSnapshot[0].status, .available)
        XCTAssertEqual(
            Attempt.recentSkillAttempts(for: skill.id, in: recordedAttemptsSnapshot),
            [evaluation.attempt]
        )
    }
}
