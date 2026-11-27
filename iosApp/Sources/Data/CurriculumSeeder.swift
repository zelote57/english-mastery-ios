import Foundation
import SwiftData

@MainActor
enum CurriculumSeeder {
    enum SeedError: Error, Equatable {
        case resourceNotFound(String)
        case invalidCurriculum(String)
    }

    private struct SeedPayload: Decodable {
        let version: Int?
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
        guard let url = bundle.url(forResource: resourceName, withExtension: "json")
            ?? bundle.url(forResource: resourceName, withExtension: "json", subdirectory: "Resources") else {
            throw SeedError.resourceNotFound("\(resourceName).json")
        }
        let data = try Data(contentsOf: url)
        try seed(from: data, in: context)
    }

    static func seed(from jsonData: Data, in context: ModelContext) throws {
        let payload = try JSONDecoder().decode(SeedPayload.self, from: jsonData)
        guard (1...2).contains(payload.version ?? 1) else {
            throw SeedError.invalidCurriculum("Unsupported curriculum version.")
        }
        guard !payload.phases.isEmpty else {
            throw SeedError.invalidCurriculum("Curriculum seed contains no phases.")
        }

        if try context.fetchCount(FetchDescriptor<PhaseModel>()) > 0 {
            try reconcile(payload, in: context)
            return
        }

        do {
            try insert(payload, in: context)
        } catch {
            context.rollback()
            throw error
        }
    }

    private static func insert(_ payload: SeedPayload, in context: ModelContext) throws {
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

    private static func reconcile(_ payload: SeedPayload, in context: ModelContext) throws {
        let phases = try context.fetch(FetchDescriptor<PhaseModel>())
        let skills = try context.fetch(FetchDescriptor<SkillModel>())
        let questions = try context.fetch(FetchDescriptor<QuestionModel>())
        guard try context.fetchCount(FetchDescriptor<UserModel>()) == 1 else {
            throw SeedError.invalidCurriculum("Existing learner profile is missing or duplicated.")
        }
        let phasesById = Dictionary(uniqueKeysWithValues: phases.map { ($0.id, $0) })
        let skillsById = Dictionary(uniqueKeysWithValues: skills.map { ($0.id, $0) })
        let questionsById = Dictionary(uniqueKeysWithValues: questions.map { ($0.id, $0) })

        do {
            for item in payload.phases {
                guard let phase = phasesById[item.id], phase.level == item.level,
                      PhaseLevel(rawValue: item.level) != nil, PhaseStatus(rawValue: item.status) != nil else {
                    throw SeedError.invalidCurriculum("Existing phase does not match curriculum: \(item.id)")
                }
                if phase.title != item.title { phase.title = item.title }
                if phase.cambridgeAlignment != item.cambridgeAlignment { phase.cambridgeAlignment = item.cambridgeAlignment }
                if phase.order != item.order { phase.order = item.order }
            }
            for item in payload.skills {
                guard let skill = skillsById[item.id], skill.phaseId == item.phaseId,
                      phasesById[item.phaseId] != nil else {
                    throw SeedError.invalidCurriculum("Existing skill does not match curriculum: \(item.id)")
                }
                if skill.skillCode != item.skillCode { skill.skillCode = item.skillCode }
                if skill.topic != item.topic { skill.topic = item.topic }
            }
            for item in payload.questions {
                guard let type = QuestionType(rawValue: item.questionType),
                      let skill = skillsById[item.skillId] else {
                    throw SeedError.invalidCurriculum("Invalid question: \(item.id)")
                }
                let updated = Question(
                    id: item.id, skillId: item.skillId, prompt: item.prompt,
                    correctAnswer: item.correctAnswer, acceptedSynonyms: item.acceptedSynonyms,
                    distractors: item.distractors, questionType: type,
                    isPlacementEligible: item.isPlacementEligible
                )
                if let question = questionsById[item.id] {
                    guard question.skillId == item.skillId else {
                        throw SeedError.invalidCurriculum("Existing question has a different skill: \(item.id)")
                    }
                    if question.toDomain() != updated { question.updateContent(from: updated) }
                } else {
                    let question = QuestionModel(from: updated)
                    context.insert(question)
                    question.skill = skill
                }
            }
            if context.hasChanges { try context.save() }
        } catch {
            context.rollback()
            throw error
        }
    }
}
