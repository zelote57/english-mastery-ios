import Foundation
import SwiftData

/// SwiftData persistence model for a CEFR/Cambridge curriculum phase (`specs/04-data-models.json`).
@Model
final class PhaseModel {
    @Attribute(.unique) var id: UUID
    var level: String
    var title: String
    var cambridgeAlignment: String
    var order: Int
    var status: String
    @Relationship(deleteRule: .cascade, inverse: \SkillModel.phase) var skills: [SkillModel] = []

    init(
        id: UUID = UUID(),
        level: String,
        title: String,
        cambridgeAlignment: String,
        order: Int,
        status: String = PhaseStatus.locked.rawValue
    ) {
        self.id = id
        self.level = level
        self.title = title
        self.cambridgeAlignment = cambridgeAlignment
        self.order = order
        self.status = status
    }

    convenience init(from phase: Phase) {
        self.init(
            id: phase.id,
            level: phase.level.rawValue,
            title: phase.title,
            cambridgeAlignment: phase.cambridgeAlignment,
            order: phase.order,
            status: phase.status.rawValue
        )
    }

    func toDomain() -> Phase? {
        guard let parsedLevel = PhaseLevel(rawValue: level),
              let parsedStatus = PhaseStatus(rawValue: status) else {
            return nil
        }
        return Phase(
            id: id,
            level: parsedLevel,
            title: title,
            cambridgeAlignment: cambridgeAlignment,
            order: order,
            status: parsedStatus
        )
    }
}
