import Foundation

/// Top-level navigation destinations mirroring `specs/05-ui-flows.md`.
enum AppState: Equatable, Sendable {
    case gatingModel
    case onboarding
    case placementTest
    case home
    case testInProgress
    case reviewingFeedback
    case mistakeDrill
}

/// Readiness states for on-device LLM provisioning (`ModelGateView`).
enum ModelGateStatus: Equatable, Sendable {
    case loading
    case downloading(Double)
    case ready
    case error(String)
}
