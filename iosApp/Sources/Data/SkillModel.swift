// SkillModel.swift
// SwiftData representation of a curriculum skill.

import SwiftData

@Model
public final class SkillModel {
    @Attribute(.unique) public var id: UUID
    public var skillCode: String
    public var topic: String
    // Relationship to owning phase (inverse defined in PhaseModel).
    @Relationship(inverse: "skills") public var phase: PhaseModel?
    // Relationship to its questions.
    @Relationship(inverse: "skill") public var questions: [QuestionModel] = []

    public init(id: UUID = UUID(), skillCode: String, topic: String, phase: PhaseModel? = nil) {
        self.id = id
        self.skillCode = skillCode
        self.topic = topic
        self.phase = phase
    }
}
