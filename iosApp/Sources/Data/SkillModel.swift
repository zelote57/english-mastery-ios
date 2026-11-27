// SkillModel.swift
// SwiftData representation of a curriculum skill.

import Foundation
import SwiftData

@Model
public final class SkillModel {
    @Attribute(.unique) public var id: UUID
    public var skillCode: String
    public var topic: String
    public var phaseId: UUID?

    public init(id: UUID = UUID(), skillCode: String, topic: String, phaseId: UUID? = nil) {
        self.id = id
        self.skillCode = skillCode
        self.topic = topic
        self.phaseId = phaseId
    }
}
