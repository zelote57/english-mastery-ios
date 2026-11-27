import Foundation
import SwiftData

/// Namespace and SwiftData `ModelContainer` factory for the Data layer.
@MainActor
enum DataLayer {
    static func makeModelContainer(inMemory: Bool = false) throws -> ModelContainer {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: inMemory)
        return try ModelContainer(
            for: UserModel.self,
            PhaseModel.self,
            SkillModel.self,
            QuestionModel.self,
            AttemptModel.self,
            AnswerRecordModel.self,
            configurations: configuration
        )
    }
}
