// UserModel.swift
// SwiftData representation of the learner profile.

import Foundation
import SwiftData

@Model
public final class UserModel {
    @Attribute(.unique) public var id: UUID
    public var name: String
    public var currentPhaseId: UUID
    public var createdAt: Date
    public var streakDays: Int
    public var lastPracticeDate: Date?
    public var hasCompletedOnboarding: Bool
    // Store as raw string for SwiftData compatibility; converted to PhaseLevel in domain layer.
    public var placementPhaseCode: String?

    public init(
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
}
