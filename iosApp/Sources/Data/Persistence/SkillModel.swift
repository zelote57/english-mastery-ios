import Foundation
import SwiftData

/// SwiftData persistence model for an individual grammar/Use of English skill (`specs/04-data-models.json`).
@Model
final class SkillModel {
    @Attribute(.unique) var id: UUID
    var skillCode: String
    var topic: String
    var phaseId: UUID
    var isPassed: Bool
    var bestScore: Double
    var phase: PhaseModel?
    @Relationship(deleteRule: .cascade, inverse: \QuestionModel.skill) var questions: [QuestionModel] = []

    init(
        id: UUID = UUID(),
        skillCode: String,
        topic: String,
        phaseId: UUID,
        isPassed: Bool = false,
        bestScore: Double = 0.0,
        phase: PhaseModel? = nil
    ) {
        self.id = id
        self.skillCode = skillCode
        self.topic = topic
        self.phaseId = phaseId
        self.isPassed = isPassed
        self.bestScore = bestScore
        self.phase = phase
    }

    convenience init(from skill: Skill, phase: PhaseModel? = nil) {
        self.init(
            id: skill.id,
            skillCode: skill.skillCode,
            topic: skill.topic,
            phaseId: skill.phaseId,
            isPassed: skill.isPassed,
            bestScore: skill.bestScore,
            phase: phase
        )
    }

    func update(from skill: Skill) {
        isPassed = skill.isPassed
        bestScore = skill.bestScore
    }

    func toDomain() -> Skill {
        Skill(
            id: id,
            skillCode: skillCode,
            topic: topic,
            phaseId: phaseId,
            isPassed: isPassed,
            bestScore: bestScore
        )
    }
}
