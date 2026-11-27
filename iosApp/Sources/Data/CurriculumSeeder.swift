import Foundation
import SwiftData

/// Loads `seed-curriculum.json` on first launch and populates phases, skills, questions, and default user.
@MainActor
enum CurriculumSeeder {
    enum SeedError: Error, Equatable {
        case resourceNotFound(String)
        case invalidCurriculum(String)
    }

    private struct SeedPayload: Decodable {
        let phases: [SeedPhase]
        let skills: [SeedSkill]
        let questions: [SeedQuestion]
    }

    private struct SeedPhase: Decodable {
        let id: UUID
        let level: String
        let title: String
        let cambridgeAlignment: String
        let order: Int
        let status: String
    }

    private struct SeedSkill: Decodable {
        let id: UUID
        let skillCode: String
        let topic: String
        let phaseId: UUID
    }

    private struct SeedQuestion: Decodable {
        let id: UUID
        let skillId: UUID
        let prompt: String
        let correctAnswer: String
        let acceptedSynonyms: [String]
        let distractors: [String]
        let questionType: String
        let isPlacementEligible: Bool
    }

    static func seedIfNeeded(
        in context: ModelContext,
        bundle: Bundle = .main,
        resourceName: String = "seed-curriculum"
    ) throws {
        let existingPhaseCount = try context.fetchCount(FetchDescriptor<PhaseModel>())
        guard existingPhaseCount == 0 else { return }

        guard let url = bundle.url(forResource: resourceName, withExtension: "json")
            ?? bundle.url(forResource: resourceName, withExtension: "json", subdirectory: "Resources") else {
            throw SeedError.resourceNotFound("\(resourceName).json")
        }
        let data = try Data(contentsOf: url)
        try seed(from: data, in: context)
    }

    static func seed(from jsonData: Data, in context: ModelContext) throws {
        let existingPhaseCount = try context.fetchCount(FetchDescriptor<PhaseModel>())
        guard existingPhaseCount == 0 else { return }

        let payload = try JSONDecoder().decode(SeedPayload.self, from: jsonData)
        guard !payload.phases.isEmpty else {
            throw SeedError.invalidCurriculum("Curriculum seed contains no phases.")
        }

        var phasesById: [UUID: PhaseModel] = [:]
        for item in payload.phases {
            guard PhaseLevel(rawValue: item.level) != nil else {
                throw SeedError.invalidCurriculum("Invalid phase level: \(item.level)")
            }
            guard PhaseStatus(rawValue: item.status) != nil else {
                throw SeedError.invalidCurriculum("Invalid phase status: \(item.status)")
            }
            let phase = PhaseModel(
                id: item.id,
                level: item.level,
                title: item.title,
                cambridgeAlignment: item.cambridgeAlignment,
                order: item.order,
                status: item.status
            )
            context.insert(phase)
            phasesById[phase.id] = phase
        }

        var skillsById: [UUID: SkillModel] = [:]
        for item in payload.skills {
            guard let phase = phasesById[item.phaseId] else {
                throw SeedError.invalidCurriculum("Skill \(item.skillCode) references unknown phase \(item.phaseId)")
            }
            let skill = SkillModel(
                id: item.id,
                skillCode: item.skillCode,
                topic: item.topic,
                phaseId: item.phaseId
            )
            context.insert(skill)
            // Link after both parent and child belong to the same ModelContext.
            skill.phase = phase
            skillsById[skill.id] = skill
        }

        for item in payload.questions {
            guard let skill = skillsById[item.skillId] else {
                throw SeedError.invalidCurriculum("Question \(item.id) references unknown skill \(item.skillId)")
            }
            guard QuestionType(rawValue: item.questionType) != nil else {
                throw SeedError.invalidCurriculum("Invalid questionType: \(item.questionType)")
            }
            let question = QuestionModel(
                id: item.id,
                skillId: item.skillId,
                prompt: item.prompt,
                correctAnswer: item.correctAnswer,
                acceptedSynonyms: item.acceptedSynonyms,
                distractors: item.distractors,
                questionType: item.questionType,
                isPlacementEligible: item.isPlacementEligible
            )
            context.insert(question)
            question.skill = skill
        }

        if try context.fetchCount(FetchDescriptor<UserModel>()) == 0 {
            guard let initialPhase = payload.phases.min(by: { $0.order < $1.order }) else {
                throw SeedError.invalidCurriculum("Curriculum seed contains no phases.")
            }
            let defaultUser = UserModel(
                name: "Learner",
                currentPhaseId: initialPhase.id,
                hasCompletedOnboarding: false
            )
            context.insert(defaultUser)
        }

        try context.save()
    }
}
