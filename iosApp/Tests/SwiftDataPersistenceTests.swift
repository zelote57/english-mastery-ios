import SwiftData
import XCTest
@testable import EnglishMastery

@MainActor
final class SwiftDataPersistenceTests: XCTestCase {
    private static let expectedSkillCodes = [
        "A1-01", "A1-02", "A1-03", "A1-04", "A1-05",
        "A2_INIT-01", "A2_INIT-02", "A2_INIT-03",
        "A2_INT-01", "A2_INT-02", "A2_INT-03",
        "A2_ADV-01", "A2_ADV-02", "A2_ADV-03",
        "B1_INIT-01", "B1_INIT-02", "B1_INIT-03",
        "B1_INT-01", "B1_INT-02", "B1_INT-03",
        "B1_ADV-01", "B1_ADV-02", "B1_ADV-03",
        "B2_INIT-01", "B2_INIT-02", "B2_INIT-03",
        "B2_ADV-01", "B2_ADV-02", "B2_ADV-03",
    ]

    private func makeInMemoryContainer() throws -> ModelContainer {
        try DataLayer.makeModelContainer(inMemory: true)
    }

    func testSeedCurriculumMeetsSpecInvariantsAndIdempotency() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext

        try CurriculumSeeder.seedIfNeeded(in: context)

        let users = try context.fetch(FetchDescriptor<UserModel>())
        let phases = try context.fetch(FetchDescriptor<PhaseModel>(sortBy: [SortDescriptor(\.order)]))
        let skills = try context.fetch(FetchDescriptor<SkillModel>())
        let questions = try context.fetch(FetchDescriptor<QuestionModel>())

        XCTAssertEqual(users.count, 1)
        XCTAssertEqual(phases.count, 9)
        XCTAssertEqual(skills.count, 29)
        XCTAssertEqual(questions.count, 29 * 16)

        let domainUser = try XCTUnwrap(users.first).toDomain()
        XCTAssertEqual(domainUser.name, "Learner")
        XCTAssertFalse(domainUser.hasCompletedOnboarding)
        XCTAssertNil(domainUser.placementPhaseCode)
        XCTAssertEqual(domainUser.streakDays, 0)
        XCTAssertEqual(domainUser.currentPhaseId, phases[0].id)

        let domainPhases = phases.compactMap { $0.toDomain() }
        XCTAssertEqual(domainPhases.map(\.level), PhaseLevel.allCases)
        XCTAssertEqual(domainPhases.first?.status, .available)
        XCTAssertTrue(domainPhases.dropFirst().allSatisfy { $0.status == .locked })

        XCTAssertEqual(Set(skills.map(\.skillCode)), Set(Self.expectedSkillCodes))
        XCTAssertTrue(skills.allSatisfy { !$0.isPassed && $0.bestScore == 0.0 })

        let skillsById = Dictionary(uniqueKeysWithValues: skills.map { ($0.id, $0) })
        for skill in skills {
            XCTAssertGreaterThan(skill.questions.count, 15, "Expected >15 questions for \(skill.skillCode)")
        }

        var placementPerPhase: [UUID: Int] = [:]
        for questionModel in questions {
            let question = try XCTUnwrap(questionModel.toDomain())
            XCTAssertFalse(question.prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            XCTAssertFalse(question.correctAnswer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

            if question.questionType == .multipleChoice {
                XCTAssertEqual(question.distractors.count, 3)
                let normalizedAnswer = ScoringEngine.normalize(question.correctAnswer, stripTerminalPunctuation: false)
                let normalizedDistractors = question.distractors.map {
                    ScoringEngine.normalize($0, stripTerminalPunctuation: false)
                }
                XCTAssertFalse(normalizedDistractors.contains(normalizedAnswer))
            }

            if question.isPlacementEligible {
                let skill = try XCTUnwrap(skillsById[question.skillId])
                placementPerPhase[skill.phaseId, default: 0] += 1
            }
        }

        XCTAssertEqual(placementPerPhase.values.reduce(0, +), 18)
        for phase in phases {
            XCTAssertEqual(placementPerPhase[phase.id], 2, "Expected 2 placement questions for \(phase.level)")
        }

        // Re-running seedIfNeeded must remain idempotent.
        try CurriculumSeeder.seedIfNeeded(in: context)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<UserModel>()), 1)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<PhaseModel>()), 9)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<SkillModel>()), 29)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<QuestionModel>()), 29 * 16)
    }

    func testDomainRoundTripAttemptPersistenceAndCascadeDelete() throws {
        let container = try makeInMemoryContainer()
        let seedContext = container.mainContext
        try CurriculumSeeder.seedIfNeeded(in: seedContext)

        let userModel = try XCTUnwrap(seedContext.fetch(FetchDescriptor<UserModel>()).first)
        let phaseModels = try seedContext.fetch(FetchDescriptor<PhaseModel>(sortBy: [SortDescriptor(\.order)]))
        let skillModels = try seedContext.fetch(FetchDescriptor<SkillModel>())
        let questionModels = try seedContext.fetch(FetchDescriptor<QuestionModel>())

        let phases = phaseModels.compactMap { $0.toDomain() }
        let skills = skillModels.map { $0.toDomain() }
        let questions = questionModels.compactMap { $0.toDomain() }
        let placementQuestions = questions.filter(\.isPlacementEligible)
        XCTAssertEqual(placementQuestions.count, 18)

        let skillsById = Dictionary(uniqueKeysWithValues: skills.map { ($0.id, $0) })
        let orderedPhasesById = Dictionary(uniqueKeysWithValues: phases.map { ($0.id, $0.order) })
        let sortedPlacement = placementQuestions.sorted {
            let lhsOrder = orderedPhasesById[skillsById[$0.skillId]?.phaseId ?? UUID()] ?? 0
            let rhsOrder = orderedPhasesById[skillsById[$1.skillId]?.phaseId ?? UUID()] ?? 0
            return lhsOrder < rhsOrder
        }

        // Clear Phases 1...3, fail Phase 4 -> placed at Phase 4 (A2_ADV).
        let placementSubmissions = sortedPlacement.enumerated().map { index, question in
            let isInFirstThreePhases = index < 6
            return QuestionSubmission(
                question: question,
                userAnswer: isInFirstThreePhases ? question.correctAnswer : "incorrect",
                ragFeedback: "Ignored during placement"
            )
        }
        let placementOutcome = try PlacementEvaluationUseCase.evaluatePlacement(
            user: userModel.toDomain(),
            phases: phases,
            skills: skills,
            submissions: placementSubmissions
        )

        userModel.update(from: placementOutcome.updatedUser)
        let phaseStatusById = Dictionary(uniqueKeysWithValues: placementOutcome.updatedPhases.map { ($0.id, $0.status.rawValue) })
        for model in phaseModels {
            if let status = phaseStatusById[model.id] {
                model.status = status
            }
        }
        let placementAttempt = try XCTUnwrap(placementOutcome.attempt)
        let placementAttemptModel = AttemptModel(from: placementAttempt)
        seedContext.insert(placementAttemptModel)

        // Official skill assessment with +1.0, +0.5 partial (clears ragFeedback), and 0.0 miss (keeps ragFeedback).
        let targetSkillModel = try XCTUnwrap(skillModels.first(where: { $0.phaseId == placementOutcome.targetPhase.id }))
        let skillQuestions = questions.filter { $0.skillId == targetSkillModel.id }
        let fullQ = try XCTUnwrap(skillQuestions.first(where: { $0.questionType == .fillBlank }))
        let partialQ = Question(skillId: targetSkillModel.id, prompt: "Spelling", correctAnswer: "worked", questionType: .fillBlank)
        let failQ = Question(skillId: targetSkillModel.id, prompt: "Missed", correctAnswer: "studied", questionType: .fillBlank)
        let skillSubmissions = [
            QuestionSubmission(question: fullQ, userAnswer: fullQ.correctAnswer, ragFeedback: "Should clear"),
            QuestionSubmission(question: partialQ, userAnswer: "workd", ragFeedback: "Should clear"),
            QuestionSubmission(question: failQ, userAnswer: "completely wrong", ragFeedback: "### 💡 Regla clave"),
        ] + Array(repeating: QuestionSubmission(question: fullQ, userAnswer: fullQ.correctAnswer), count: 12)

        let skillOutcome = EvaluateAttemptUseCase.evaluate(
            user: placementOutcome.updatedUser,
            skill: targetSkillModel.toDomain(),
            phases: placementOutcome.updatedPhases,
            skills: skills,
            submissions: skillSubmissions
        )
        userModel.update(from: skillOutcome.updatedUser)
        targetSkillModel.update(from: skillOutcome.updatedSkill)
        let skillAttemptModel = AttemptModel(from: skillOutcome.attempt)
        seedContext.insert(skillAttemptModel)
        try seedContext.save()

        // Verify persisted graph from a fresh ModelContext.
        let readContext = ModelContext(container)
        let reloadedUser = try XCTUnwrap(readContext.fetch(FetchDescriptor<UserModel>()).first?.toDomain())
        XCTAssertTrue(reloadedUser.hasCompletedOnboarding)
        XCTAssertEqual(reloadedUser.placementPhaseCode, .a2Adv)
        XCTAssertEqual(reloadedUser.currentPhaseId, placementOutcome.targetPhase.id)
        XCTAssertEqual(reloadedUser.streakDays, 1)

        let reloadedPhases = try readContext.fetch(FetchDescriptor<PhaseModel>(sortBy: [SortDescriptor(\.order)]))
            .compactMap { $0.toDomain() }
        XCTAssertEqual(reloadedPhases[0...2].map(\.status), [.skippedPassed, .skippedPassed, .skippedPassed])
        XCTAssertEqual(reloadedPhases[3].status, .available)
        XCTAssertTrue(reloadedPhases[4...8].allSatisfy { $0.status == .locked })

        let targetId = targetSkillModel.id
        let reloadedSkill = try XCTUnwrap(
            readContext.fetch(FetchDescriptor<SkillModel>(predicate: #Predicate { $0.id == targetId })).first?.toDomain()
        )
        XCTAssertTrue(reloadedSkill.isPassed)
        XCTAssertEqual(reloadedSkill.bestScore, 13.5 / 15.0, accuracy: 0.0001)

        let reloadedSkillAttemptId = skillOutcome.attempt.id
        let reloadedAttemptModel = try XCTUnwrap(
            readContext.fetch(FetchDescriptor<AttemptModel>(predicate: #Predicate { $0.id == reloadedSkillAttemptId })).first
        )
        let reloadedAttempt = try XCTUnwrap(reloadedAttemptModel.toDomain())
        XCTAssertEqual(reloadedAttempt.answers.count, 15)
        let reloadedFullRecords = reloadedAttempt.answers.filter { $0.questionId == fullQ.id }
        XCTAssertEqual(reloadedFullRecords.count, 13)
        XCTAssertTrue(reloadedFullRecords.allSatisfy { $0.ragFeedback == nil })
        let reloadedPartial = try XCTUnwrap(reloadedAttempt.answers.first { $0.questionId == partialQ.id })
        XCTAssertEqual(reloadedPartial.pointsEarned, 0.5)
        XCTAssertNil(reloadedPartial.ragFeedback)
        let reloadedFail = try XCTUnwrap(reloadedAttempt.answers.first { $0.questionId == failQ.id })
        XCTAssertEqual(reloadedFail.pointsEarned, 0.0)
        XCTAssertEqual(reloadedFail.ragFeedback, "### 💡 Regla clave")

        // Deleting an AttemptModel cascades to its AnswerRecordModels.
        readContext.delete(reloadedAttemptModel)
        try readContext.save()
        XCTAssertEqual(try readContext.fetchCount(FetchDescriptor<AttemptModel>()), 1)
        XCTAssertEqual(try readContext.fetchCount(FetchDescriptor<AnswerRecordModel>()), 18)
    }

    func testCurriculumSeederThrowsOnMissingResourceOrInvalidPayload() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext

        XCTAssertThrowsError(
            try CurriculumSeeder.seedIfNeeded(in: context, bundle: .main, resourceName: "nonexistent-seed")
        ) { error in
            XCTAssertEqual(error as? CurriculumSeeder.SeedError, .resourceNotFound("nonexistent-seed.json"))
        }

        let invalidJson = Data(#"{"phases":[],"skills":[],"questions":[]}"#.utf8)
        XCTAssertThrowsError(
            try CurriculumSeeder.seed(from: invalidJson, in: context)
        ) { error in
            XCTAssertEqual(
                error as? CurriculumSeeder.SeedError,
                .invalidCurriculum("Curriculum seed contains no phases.")
            )
        }
    }

    func testCurriculumUpdatePreservesProgressAndHistoricalAnswers() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        try CurriculumSeeder.seedIfNeeded(in: context)
        let user = try XCTUnwrap(context.fetch(FetchDescriptor<UserModel>()).first)
        let phases = try context.fetch(FetchDescriptor<PhaseModel>(sortBy: [SortDescriptor(\.order)]))
        let question = try XCTUnwrap(context.fetch(FetchDescriptor<QuestionModel>()).first {
            $0.correctAnswer == "Madrid is bigger than Seville"
        })
        let skill = try XCTUnwrap(question.skill)
        let originalId = question.id
        user.hasCompletedOnboarding = true
        user.currentPhaseId = phases[1].id
        phases[0].status = PhaseStatus.completed.rawValue
        phases[1].status = PhaseStatus.available.rawValue
        skill.isPassed = true
        skill.bestScore = 0.9
        question.acceptedSynonymsJSON = "[]"
        let attemptId = UUID()
        let record = AnswerRecord(attemptId: attemptId, questionId: originalId, userAnswer: "Madrid is larger than Seville", pointsEarned: 0)
        let attempt = Attempt(id: attemptId, userId: user.id, skillId: skill.id, score: 0,
                              earnedPoints: 0, totalQuestions: 1, correctAnswers: 0, answers: [record])
        context.insert(AttemptModel(from: attempt))
        try context.save()

        try CurriculumSeeder.seedIfNeeded(in: context)
        try CurriculumSeeder.seedIfNeeded(in: context)
        let readContext = ModelContext(container)
        let savedUser = try XCTUnwrap(readContext.fetch(FetchDescriptor<UserModel>()).first)
        let savedQuestion = try XCTUnwrap(readContext.fetch(FetchDescriptor<QuestionModel>()).first { $0.id == originalId })
        let savedSkill = try XCTUnwrap(savedQuestion.skill)
        let savedAttempt = try XCTUnwrap(readContext.fetch(FetchDescriptor<AttemptModel>()).first?.toDomain())
        XCTAssertTrue(savedUser.hasCompletedOnboarding)
        XCTAssertEqual(savedUser.currentPhaseId, phases[1].id)
        XCTAssertEqual(try readContext.fetch(FetchDescriptor<PhaseModel>(sortBy: [SortDescriptor(\.order)]))[0].status, "completed")
        XCTAssertTrue(savedSkill.isPassed)
        XCTAssertEqual(savedSkill.bestScore, 0.9)
        XCTAssertEqual(savedQuestion.skillId, skill.id)
        let corrected = try XCTUnwrap(savedQuestion.toDomain())
        XCTAssertTrue(corrected.acceptedSynonyms.contains("Madrid is larger than Seville"))
        XCTAssertEqual(ScoringEngine.grade(answer: "Madrid is larger than Seville", for: corrected).pointsEarned, 1)
        XCTAssertEqual(savedAttempt.id, attemptId)
        XCTAssertEqual(savedAttempt.answers.first?.questionId, originalId)
        XCTAssertEqual(savedAttempt.answers.first?.pointsEarned, 0)
        XCTAssertEqual(try readContext.fetchCount(FetchDescriptor<QuestionModel>()), 464)
        XCTAssertEqual(try readContext.fetchCount(FetchDescriptor<AttemptModel>()), 1)
    }

    func testCorruptQuestionDataStopsSnapshotLoading() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        try CurriculumSeeder.seedIfNeeded(in: context)
        let question = try XCTUnwrap(context.fetch(FetchDescriptor<QuestionModel>()).first)
        question.acceptedSynonymsJSON = "invalid"
        try context.save()
        XCTAssertNil(question.toDomain())
        let coordinator = AppCoordinator(modelContext: context)
        coordinator.loadInitialState()
        XCTAssertEqual(coordinator.modelGateStatus, .error("Failed to load saved progress."))
        XCTAssertTrue(coordinator.questions.isEmpty)
    }

    func testPlacementAcceptsEquivalentBoringFilmTransformations() throws {
        let container = try makeInMemoryContainer()
        try CurriculumSeeder.seedIfNeeded(in: container.mainContext)
        let model = try XCTUnwrap(container.mainContext.fetch(FetchDescriptor<QuestionModel>()).first {
            $0.isPlacementEligible && $0.correctAnswer == "such a boring film"
        })
        model.acceptedSynonymsJSON = "[]"
        try container.mainContext.save()
        try CurriculumSeeder.seedIfNeeded(in: container.mainContext)
        let question = try XCTUnwrap(model.toDomain())
        for answer in ["such a dull film", "such a tedious film", "such a boring movie"] {
            XCTAssertEqual(ScoringEngine.grade(answer: answer, for: question).pointsEarned, 1)
        }
    }

    func testReconciledCurriculumGradesEquivalentAnswersAndRejectsInvalidTransformation() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        try CurriculumSeeder.seedIfNeeded(in: context)
        let questions = try context.fetch(FetchDescriptor<QuestionModel>())
        let reorder = try XCTUnwrap(questions.first {
            $0.correctAnswer == "She picked up the phone from the ground"
        })
        reorder.acceptedSynonymsJSON = "[]"
        try context.save()
        try CurriculumSeeder.seedIfNeeded(in: context)
        let alternatives = [
            ("She picked up the phone from the ground", "She picked the phone up from the ground"),
            ("We will meet at the airport tomorrow", "We will meet tomorrow at the airport"),
            ("He is my friend", "He is a friend of mine"),
            ("I haven't seen him since Monday", "I haven't seen it since Monday")
        ]
        for (answer, alternative) in alternatives {
            let model = try XCTUnwrap(questions.first { $0.correctAnswer == answer })
            let question = try XCTUnwrap(model.toDomain())
            XCTAssertEqual(ScoringEngine.grade(answer: alternative, for: question).pointsEarned, 1, alternative)
        }
        let packing = try XCTUnwrap(questions.first { $0.prompt.contains("Have you finished packing") }?.toDomain())
        XCTAssertEqual(ScoringEngine.grade(answer: "already", for: packing).pointsEarned, 1)
        let model = try XCTUnwrap(questions.first { $0.correctAnswer == "In spite of" })
        let question = try XCTUnwrap(model.toDomain())
        XCTAssertEqual(ScoringEngine.grade(answer: "In spite", for: question).pointsEarned, 0)
    }

    func testFailedCurriculumUpdateRollsBackEarlierChanges() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        try CurriculumSeeder.seedIfNeeded(in: context)
        let phase = try XCTUnwrap(context.fetch(FetchDescriptor<PhaseModel>()).first)
        let question = try XCTUnwrap(context.fetch(FetchDescriptor<QuestionModel>()).first)
        phase.title = "Old title"
        question.skillId = UUID()
        try context.save()
        XCTAssertThrowsError(try CurriculumSeeder.seedIfNeeded(in: context))
        let fresh = ModelContext(container)
        let phaseId = phase.id
        let saved = try XCTUnwrap(fresh.fetch(FetchDescriptor<PhaseModel>()).first { $0.id == phaseId })
        XCTAssertEqual(saved.title, "Old title")
    }
}
