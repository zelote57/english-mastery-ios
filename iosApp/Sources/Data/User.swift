import Foundation
import SwiftData

/// Learner profile tracking active Cambridge phase, onboarding state, and daily practice streak.
@Model
final class User {
    @Attribute(.unique) let id: UUID
    var name: String
    var currentPhaseId: UUID
    let createdAt: Date
    var streakDays: Int
    var lastPracticeDate: Date?
    var hasCompletedOnboarding: Bool
    // Store as raw string for SwiftData compatibility; converted to PhaseLevel in domain layer.
    var placementPhaseCode: String?

    init(id: UUID = UUID(),
         name: String = "Learner",
         currentPhaseId: UUID,
         createdAt: Date = Date(),
         streakDays: Int = 0,
         lastPracticeDate: Date? = nil,
         hasCompletedOnboarding: Bool = false,
         placementPhaseCode: String? = nil) {
        self.id = id
        self.name = name
        self.currentPhaseId = currentPhaseId
        self.createdAt = createdAt
        self.streakDays = streakDays
        self.lastPracticeDate = lastPracticeDate
        self.hasCompletedOnboarding = hasCompletedOnboarding
        self.placementPhaseCode = placementPhaseCode
    }

    /// Updates calendar‑day streak after a completed official skill assessment.
    func recordPractice(at date: Date, calendar: Calendar = .current) {
        guard let previousDate = lastPracticeDate else {
            streakDays = 1
            lastPracticeDate = date
            return
        }
        let previousDay = calendar.startOfDay(for: previousDate)
        let currentDay = calendar.startOfDay(for: date)
        guard let dayDelta = calendar.dateComponents([.day], from: previousDay, to: currentDay).day,
              dayDelta >= 0 else { return }
        lastPracticeDate = date
        switch dayDelta {
        case 0:
            streakDays = max(1, streakDays)
        case 1:
            streakDays += 1
        default:
            streakDays = 1
        }
    }
}
