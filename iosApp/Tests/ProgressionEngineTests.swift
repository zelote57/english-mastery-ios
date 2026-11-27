import XCTest
@testable import EnglishMastery

final class ProgressionEngineTests: XCTestCase {
    private var utcCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private func date(year: Int, month: Int, day: Int, hour: Int = 12, minute: Int = 0) -> Date {
        utcCalendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
    }

    private func makeNinePhaseCurriculum() -> (phases: [Phase], skills: [Skill]) {
        let phases = PhaseLevel.allCases.map { level in
            Phase(level: level, title: level.rawValue, cambridgeAlignment: "Cambridge \(level.rawValue)")
        }
        var skills: [Skill] = []
        for phase in phases {
            skills.append(Skill(skillCode: "\(phase.level.rawValue)-01", topic: "Topic 1", phaseId: phase.id))
            skills.append(Skill(skillCode: "\(phase.level.rawValue)-02", topic: "Topic 2", phaseId: phase.id))
        }
        return (phases, skills)
    }

    private func makeSubmissions(skillId: UUID, fullCount: Int, partialCount: Int = 0, total: Int = 15) -> [QuestionSubmission] {
        let fullQ = Question(skillId: skillId, prompt: "P", correctAnswer: "worked", questionType: .fillBlank)
        let failCount = max(0, total - fullCount - partialCount)
        return Array(repeating: QuestionSubmission(question: fullQ, userAnswer: "worked"), count: fullCount)
            + Array(repeating: QuestionSubmission(question: fullQ, userAnswer: "workd"), count: partialCount)
            + Array(repeating: QuestionSubmission(question: fullQ, userAnswer: "wrong"), count: failCount)
    }

    // MARK: - Mastery Threshold & Infinite Repetition

    func testMasteryThresholdPassesAtZeroPointEightAndFailsBelow() {
        let (phases, skills) = makeNinePhaseCurriculum()
        var phase1 = phases[0]
        phase1.status = .available
        let updatedPhases = [phase1] + Array(phases.dropFirst())
        let user = User(currentPhaseId: phase1.id, hasCompletedOnboarding: true)
        let skill = skills[0]

        let belowThreshold = EvaluateAttemptUseCase.evaluate(
            user: user,
            skill: skill,
            phases: updatedPhases,
            skills: skills,
            submissions: makeSubmissions(skillId: skill.id, fullCount: 11, partialCount: 1) // 11.5 / 15 = 0.7667
        )
        XCTAssertFalse(belowThreshold.updatedSkill.isPassed)

        let exactThresholdViaPartial = EvaluateAttemptUseCase.evaluate(
            user: user,
            skill: skill,
            phases: updatedPhases,
            skills: skills,
            submissions: makeSubmissions(skillId: skill.id, fullCount: 11, partialCount: 2) // 12.0 / 15 = 0.80
        )
        XCTAssertTrue(exactThresholdViaPartial.updatedSkill.isPassed)
        XCTAssertEqual(exactThresholdViaPartial.updatedSkill.bestScore, 0.80, accuracy: 0.0001)

        let explicit79Percent = EvaluateAttemptUseCase.evaluate(
            user: user,
            skill: skill,
            phases: updatedPhases,
            skills: skills,
            submissions: makeSubmissions(skillId: skill.id, fullCount: 79, total: 100)
        )
        XCTAssertFalse(explicit79Percent.updatedSkill.isPassed)
    }

    func testInfiniteRepetitionPreservesIsPassedAndMonotonicBestScore() {
        let (phases, skills) = makeNinePhaseCurriculum()
        let user = User(currentPhaseId: phases[0].id, hasCompletedOnboarding: true)
        var skill = skills[0]
        skill.bestScore = 0.80
        skill.isPassed = true

        let lowerRetake = EvaluateAttemptUseCase.evaluate(
            user: user,
            skill: skill,
            phases: phases,
            skills: skills,
            submissions: makeSubmissions(skillId: skill.id, fullCount: 6) // 0.40
        )
        XCTAssertEqual(lowerRetake.attempt.score, 0.40, accuracy: 0.0001)
        XCTAssertEqual(lowerRetake.updatedSkill.bestScore, 0.80, accuracy: 0.0001)
        XCTAssertTrue(lowerRetake.updatedSkill.isPassed)

        let higherRetake = EvaluateAttemptUseCase.evaluate(
            user: lowerRetake.updatedUser,
            skill: lowerRetake.updatedSkill,
            phases: lowerRetake.updatedPhases,
            skills: skills,
            submissions: makeSubmissions(skillId: skill.id, fullCount: 14) // 0.9333
        )
        XCTAssertEqual(higherRetake.updatedSkill.bestScore, 14.0 / 15.0, accuracy: 0.0001)
        XCTAssertTrue(higherRetake.updatedSkill.isPassed)
    }

    // MARK: - 9-Phase Unlocking & SkippedPassed Isolation

    func testPhaseUnlocksOnlyWhenAllSkillsPassAndPhaseNineCompletesCleanly() {
        var (phases, skills) = makeNinePhaseCurriculum()
        phases[0].status = .available
        var user = User(currentPhaseId: phases[0].id, hasCompletedOnboarding: true)

        // Pass 1 of 2 skills in Phase 1 -> Phase 1 stays available
        let firstSkillPass = EvaluateAttemptUseCase.evaluate(
            user: user,
            skill: skills[0],
            phases: phases,
            skills: skills,
            submissions: makeSubmissions(skillId: skills[0].id, fullCount: 12)
        )
        XCTAssertFalse(firstSkillPass.didCompleteActivePhase)
        XCTAssertEqual(firstSkillPass.updatedUser.currentPhaseId, phases[0].id)
        XCTAssertEqual(firstSkillPass.updatedPhases[1].status, .locked)

        // Pass 2 of 2 skills -> Phase 1 completed, Phase 2 available
        skills[0] = firstSkillPass.updatedSkill
        let secondSkillPass = EvaluateAttemptUseCase.evaluate(
            user: firstSkillPass.updatedUser,
            skill: skills[1],
            phases: firstSkillPass.updatedPhases,
            skills: skills,
            submissions: makeSubmissions(skillId: skills[1].id, fullCount: 13)
        )
        XCTAssertTrue(secondSkillPass.didCompleteActivePhase)
        XCTAssertEqual(secondSkillPass.updatedPhases[0].status, .completed)
        XCTAssertEqual(secondSkillPass.updatedPhases[1].status, .available)
        XCTAssertEqual(secondSkillPass.updatedUser.currentPhaseId, phases[1].id)
        XCTAssertEqual(secondSkillPass.unlockedPhase?.level, .a2Init)

        // Phase 9 (B2_ADV) completion marks completed with no overflow
        let phase9 = phases[8]
        var phase9Phases = phases
        for idx in 0..<8 { phase9Phases[idx].status = .completed }
        phase9Phases[8].status = .available
        let phase9Skills = skills.filter { $0.phaseId == phase9.id }
        var prePassedFirst = phase9Skills[0]
        prePassedFirst.isPassed = true
        prePassedFirst.bestScore = 0.85
        let allSkillsWithPhase9Progress = skills.map { $0.id == prePassedFirst.id ? prePassedFirst : $0 }
        user.currentPhaseId = phase9.id

        let finalPhaseOutcome = EvaluateAttemptUseCase.evaluate(
            user: user,
            skill: phase9Skills[1],
            phases: phase9Phases,
            skills: allSkillsWithPhase9Progress,
            submissions: makeSubmissions(skillId: phase9Skills[1].id, fullCount: 15)
        )
        XCTAssertTrue(finalPhaseOutcome.didCompleteActivePhase)
        XCTAssertNil(finalPhaseOutcome.unlockedPhase)
        XCTAssertEqual(finalPhaseOutcome.updatedPhases[8].status, .completed)
        XCTAssertEqual(finalPhaseOutcome.updatedUser.currentPhaseId, phase9.id)
    }

    func testPracticingSkippedPassedPhaseNeverMovesCurrentPhaseId() {
        var (phases, skills) = makeNinePhaseCurriculum()
        phases[0].status = .skippedPassed
        phases[4].status = .available
        let user = User(currentPhaseId: phases[4].id, hasCompletedOnboarding: true, placementPhaseCode: .b1Init)

        var a1Skill1 = skills[0]
        a1Skill1.isPassed = true
        a1Skill1.bestScore = 0.80
        let updatedSkills = skills.map { $0.id == a1Skill1.id ? a1Skill1 : $0 }

        let outcome = EvaluateAttemptUseCase.evaluate(
            user: user,
            skill: skills[1],
            phases: phases,
            skills: updatedSkills,
            submissions: makeSubmissions(skillId: skills[1].id, fullCount: 14)
        )
        XCTAssertTrue(outcome.updatedSkill.isPassed)
        XCTAssertFalse(outcome.didCompleteActivePhase)
        XCTAssertEqual(outcome.updatedUser.currentPhaseId, phases[4].id)
        XCTAssertEqual(outcome.updatedPhases[0].status, .skippedPassed)
    }

    func testSkillDisplayStatesCoverAllFourVisualBadges() {
        var phaseAvailable = Phase(level: .a2Init, title: "A2", cambridgeAlignment: "A2 Key", status: .available)
        let phaseSkipped = Phase(level: .a1, title: "A1", cambridgeAlignment: "Pre-A2", status: .skippedPassed)
        let phaseLocked = Phase(level: .b2Adv, title: "B2", cambridgeAlignment: "B2 First", status: .locked)

        let passedSkill = Skill(skillCode: "A1-01", topic: "T", phaseId: phaseSkipped.id, isPassed: true, bestScore: 0.85)
        let skippedSkill = Skill(skillCode: "A1-02", topic: "T", phaseId: phaseSkipped.id, isPassed: false)
        let availableSkill = Skill(skillCode: "A2-01", topic: "T", phaseId: phaseAvailable.id, isPassed: false)
        let lockedSkill = Skill(skillCode: "B2-01", topic: "T", phaseId: phaseLocked.id, isPassed: false)

        XCTAssertEqual(passedSkill.displayState(in: phaseSkipped), .passed)
        XCTAssertEqual(skippedSkill.displayState(in: phaseSkipped), .skippedPassed)
        XCTAssertEqual(availableSkill.displayState(in: phaseAvailable), .available)
        phaseAvailable.status = .completed
        XCTAssertEqual(availableSkill.displayState(in: phaseAvailable), .available)
        XCTAssertEqual(lockedSkill.displayState(in: phaseLocked), .locked)
    }

    // MARK: - Onboarding & 18-Question Placement Routing

    func testStartFromScratchRoutesToPhaseOneA1() throws {
        let (phases, _) = makeNinePhaseCurriculum()
        let user = User(currentPhaseId: phases[0].id)

        let outcome = try PlacementEvaluationUseCase.startFromScratch(user: user, phases: phases)
        XCTAssertNil(outcome.attempt)
        XCTAssertEqual(outcome.targetPhase.level, .a1)
        XCTAssertEqual(outcome.updatedUser.currentPhaseId, phases[0].id)
        XCTAssertNil(outcome.updatedUser.placementPhaseCode)
        XCTAssertTrue(outcome.updatedUser.hasCompletedOnboarding)
        XCTAssertEqual(outcome.updatedPhases[0].status, .available)
        XCTAssertTrue(outcome.updatedPhases.dropFirst().allSatisfy { $0.status == .locked })
    }

    func testPlacementStopsAtFirstFailedBlockEvenIfHigherBlocksScorePerfectly() throws {
        let (phases, skills) = makeNinePhaseCurriculum()
        let user = User(currentPhaseId: phases[0].id)

        // Phase 1: 2.0/2.0, Phase 2: 1.5/2.0 (1 exact + 1 Levenshtein typo), Phase 3: 1.0/2.0 (< 1.5 -> K=3), Phases 4..9: 2.0/2.0
        var submissions: [QuestionSubmission] = []
        for (index, phase) in phases.enumerated() {
            let phaseSkill = skills.first { $0.phaseId == phase.id }!
            let q1 = Question(skillId: phaseSkill.id, prompt: "Q1", correctAnswer: "worked", questionType: .fillBlank, isPlacementEligible: true)
            let q2 = Question(skillId: phaseSkill.id, prompt: "Q2", correctAnswer: "studied", questionType: .fillBlank, isPlacementEligible: true)

            switch index {
            case 1:
                submissions.append(QuestionSubmission(question: q1, userAnswer: "worked"))
                submissions.append(QuestionSubmission(question: q2, userAnswer: "studid")) // +0.5 -> total 1.5
            case 2:
                submissions.append(QuestionSubmission(question: q1, userAnswer: "worked"))
                submissions.append(QuestionSubmission(question: q2, userAnswer: "wrong"))  // 0.0 -> total 1.0
            default:
                submissions.append(QuestionSubmission(question: q1, userAnswer: "worked"))
                submissions.append(QuestionSubmission(question: q2, userAnswer: "studied"))
            }
        }

        let outcome = try PlacementEvaluationUseCase.evaluatePlacement(
            user: user,
            phases: phases,
            skills: skills,
            submissions: submissions
        )

        XCTAssertEqual(outcome.targetPhase.level, .a2Int)
        XCTAssertEqual(outcome.updatedUser.currentPhaseId, phases[2].id)
        XCTAssertEqual(outcome.updatedUser.placementPhaseCode, .a2Int)
        XCTAssertTrue(outcome.updatedUser.hasCompletedOnboarding)
        XCTAssertEqual(outcome.updatedUser.streakDays, 0)
        XCTAssertEqual(outcome.attempt?.attemptType, .placementTest)
        XCTAssertNil(outcome.attempt?.skillId)
        XCTAssertEqual(outcome.updatedPhases[0].status, .skippedPassed)
        XCTAssertEqual(outcome.updatedPhases[1].status, .skippedPassed)
        XCTAssertEqual(outcome.updatedPhases[2].status, .available)
        XCTAssertTrue(outcome.updatedPhases[3...8].allSatisfy { $0.status == .locked })
    }

    func testPlacementBoundariesAtPhaseOneAndPerfectEighteenOfEighteenAtPhaseNine() throws {
        let (phases, skills) = makeNinePhaseCurriculum()
        let user = User(currentPhaseId: phases[0].id)

        func buildSubmissions(failingPhaseIndices: Set<Int>) -> [QuestionSubmission] {
            phases.enumerated().flatMap { index, phase -> [QuestionSubmission] in
                let phaseSkill = skills.first { $0.phaseId == phase.id }!
                let q1 = Question(skillId: phaseSkill.id, prompt: "Q1", correctAnswer: "worked", questionType: .fillBlank, isPlacementEligible: true)
                let q2 = Question(skillId: phaseSkill.id, prompt: "Q2", correctAnswer: "went", questionType: .fillBlank, isPlacementEligible: true)
                if failingPhaseIndices.contains(index) {
                    return [
                        QuestionSubmission(question: q1, userAnswer: "worked"),
                        QuestionSubmission(question: q2, userAnswer: "wrong")
                    ]
                }
                return [
                    QuestionSubmission(question: q1, userAnswer: "worked"),
                    QuestionSubmission(question: q2, userAnswer: "went")
                ]
            }
        }

        let placeAtOne = try PlacementEvaluationUseCase.evaluatePlacement(
            user: user,
            phases: phases,
            skills: skills,
            submissions: buildSubmissions(failingPhaseIndices: [0])
        )
        XCTAssertEqual(placeAtOne.targetPhase.level, .a1)
        XCTAssertEqual(placeAtOne.updatedPhases[0].status, .available)
        XCTAssertTrue(placeAtOne.updatedPhases.dropFirst().allSatisfy { $0.status == .locked })

        let perfectScore = try PlacementEvaluationUseCase.evaluatePlacement(
            user: user,
            phases: phases,
            skills: skills,
            submissions: buildSubmissions(failingPhaseIndices: [])
        )
        let perfectAttempt = try XCTUnwrap(perfectScore.attempt, "placement attempt should not be nil when all 18 blocks pass")
        XCTAssertEqual(perfectAttempt.score, 1.0, accuracy: 0.0001)
        XCTAssertEqual(perfectScore.targetPhase.level, .b2Adv)
        XCTAssertEqual(perfectScore.updatedPhases[8].status, .available)
        XCTAssertTrue(perfectScore.updatedPhases[0..<8].allSatisfy { $0.status == .skippedPassed })
    }

    // MARK: - Streak & 5-Attempt History

    func testCalendarStreakIncrementsOnNextDayStaysSameDayAndResetsAfterGap() {
        var user = User(currentPhaseId: UUID())

        user.recordPractice(at: date(year: 2026, month: 11, day: 10, hour: 23, minute: 50), calendar: utcCalendar)
        XCTAssertEqual(user.streakDays, 1)

        // Same day earlier/later stays 1
        user.recordPractice(at: date(year: 2026, month: 11, day: 10, hour: 23, minute: 59), calendar: utcCalendar)
        XCTAssertEqual(user.streakDays, 1)

        // Next calendar day (even 10 minutes later) increments to 2
        user.recordPractice(at: date(year: 2026, month: 11, day: 11, hour: 0, minute: 5), calendar: utcCalendar)
        XCTAssertEqual(user.streakDays, 2)

        // Missed day 12 -> practice on day 13 resets to 1
        user.recordPractice(at: date(year: 2026, month: 11, day: 13, hour: 9, minute: 0), calendar: utcCalendar)
        XCTAssertEqual(user.streakDays, 1)
    }

    func testRecentSkillAttemptsFiltersExcludesPlacementAndSortsLastFiveChronologically() {
        let userId = UUID()
        let targetSkillId = UUID()
        let otherSkillId = UUID()

        let placement = Attempt(
            userId: userId, skillId: nil, attemptType: .placementTest,
            score: 1.0, earnedPoints: 18, totalQuestions: 18, correctAnswers: 18,
            timestamp: date(year: 2026, month: 11, day: 20)
        )
        let otherSkillAttempt = Attempt(
            userId: userId, skillId: otherSkillId, attemptType: .skillAssessment,
            score: 0.9, earnedPoints: 13.5, totalQuestions: 15, correctAnswers: 13,
            timestamp: date(year: 2026, month: 11, day: 21)
        )
        let targetAttempts = (1...7).map { dayOffset in
            Attempt(
                userId: userId,
                skillId: targetSkillId,
                attemptType: .skillAssessment,
                score: Double(dayOffset) / 10.0,
                earnedPoints: Double(dayOffset),
                totalQuestions: 15,
                correctAnswers: dayOffset,
                timestamp: date(year: 2026, month: 11, day: dayOffset)
            )
        }

        let recent = Attempt.recentSkillAttempts(
            for: targetSkillId,
            in: [placement, otherSkillAttempt] + targetAttempts.reversed()
        )
        XCTAssertEqual(recent.count, 5)
        XCTAssertEqual(recent.map(\.correctAnswers), [3, 4, 5, 6, 7])
    }
}
