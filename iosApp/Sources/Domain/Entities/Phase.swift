import Foundation

/// Canonical 9-stage Cambridge CEFR progression levels (`A1` through `B2_ADV`).
enum PhaseLevel: String, Codable, CaseIterable, Comparable, Sendable {
    case a1 = "A1"
    case a2Init = "A2_INIT"
    case a2Int = "A2_INT"
    case a2Adv = "A2_ADV"
    case b1Init = "B1_INIT"
    case b1Int = "B1_INT"
    case b1Adv = "B1_ADV"
    case b2Init = "B2_INIT"
    case b2Adv = "B2_ADV"

    var order: Int {
        switch self {
        case .a1: 1
        case .a2Init: 2
        case .a2Int: 3
        case .a2Adv: 4
        case .b1Init: 5
        case .b1Int: 6
        case .b1Adv: 7
        case .b2Init: 8
        case .b2Adv: 9
        }
    }

    static func < (lhs: PhaseLevel, rhs: PhaseLevel) -> Bool {
        lhs.order < rhs.order
    }
}

/// Lifecycle state of a curriculum phase for the current learner.
enum PhaseStatus: String, Codable, Sendable {
    case locked
    case available
    case completed
    case skippedPassed
}

/// Sequential CEFR curriculum stage aligned to Cambridge English qualifications.
struct Phase: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    let level: PhaseLevel
    let title: String
    let cambridgeAlignment: String
    let order: Int
    var status: PhaseStatus

    init(
        id: UUID = UUID(),
        level: PhaseLevel,
        title: String,
        cambridgeAlignment: String,
        order: Int? = nil,
        status: PhaseStatus = .locked
    ) {
        self.id = id
        self.level = level
        self.title = title
        self.cambridgeAlignment = cambridgeAlignment
        self.order = order ?? level.order
        self.status = status
    }
}
