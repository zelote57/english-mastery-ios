// PhaseModel.swift
// SwiftData representation of a curriculum phase.

import SwiftData

@Model
public final class PhaseModel {
    @Attribute(.unique) public var id: UUID
    public var level: String
    public var title: String
    public var cambridgeAlignment: String
    public var order: Int
    public var status: String
    // Relationship to its skills (inverse defined in SkillModel).
    @Relationship(inverse: "phase") public var skills: [SkillModel] = []

    public init(id: UUID = UUID(), level: String, title: String, cambridgeAlignment: String, order: Int, status: String) {
        self.id = id
        self.level = level
        self.title = title
        self.cambridgeAlignment = cambridgeAlignment
        self.order = order
        self.status = status
    }
}
