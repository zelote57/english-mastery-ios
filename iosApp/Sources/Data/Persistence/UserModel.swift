import Foundation
import SwiftData

/// SwiftData persistence model for the learner profile (`specs/04-data-models.json`).
@Model
final class UserModel {
    @Attribute(.unique) var id: UUID
    var name: String
    var currentPhaseId: UUID
    var createdAt: Date
    var streakDays: Int
    var lastPracticeDate: Date?
    var hasCompletedOnboarding: Bool
    var placementPhaseCode: String?

    init(
        id: UUID = UUID(),
        name: String = "Learner",
        currentPhaseId: UUID,
        createdAt: Date = Date(),
        streakDays: Int = 0,
        lastPracticeDate: Date? = nil,
        hasCompletedOnboarding: Bool = false,
        placementPhaseCode: String? = nil
    ) {
        self.id = id
        self.name = name
        self.currentPhaseId = currentPhaseId
        self.createdAt = createdAt
        self.streakDays = streakDays
        self.lastPracticeDate = lastPracticeDate
        self.hasCompletedOnboarding = hasCompletedOnboarding
        self.placementPhaseCode = placementPhaseCode
    }

    convenience init(from user: User) {
        self.init(
            id: user.id,
            name: user.name,
            currentPhaseId: user.currentPhaseId,
            createdAt: user.createdAt,
            streakDays: user.streakDays,
            lastPracticeDate: user.lastPracticeDate,
            hasCompletedOnboarding: user.hasCompletedOnboarding,
            placementPhaseCode: user.placementPhaseCode?.rawValue
        )
    }

    func update(from user: User) {
        name = user.name
        currentPhaseId = user.currentPhaseId
        streakDays = user.streakDays
        lastPracticeDate = user.lastPracticeDate
        hasCompletedOnboarding = user.hasCompletedOnboarding
        placementPhaseCode = user.placementPhaseCode?.rawValue
    }

    func toDomain() -> User {
        User(
            id: id,
            name: name,
            currentPhaseId: currentPhaseId,
            createdAt: createdAt,
            streakDays: streakDays,
            lastPracticeDate: lastPracticeDate,
            hasCompletedOnboarding: hasCompletedOnboarding,
            placementPhaseCode: placementPhaseCode.flatMap(PhaseLevel.init(rawValue:))
        )
    }
}
