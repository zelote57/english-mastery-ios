import SwiftUI
import SwiftData

#if RAG_DIAGNOSTICS
@main
struct EnglishMasteryApp: App {
    var body: some Scene {
        WindowGroup {
            RAGDiagnosticView()
        }
    }
}
#else
@main
struct EnglishMasteryApp: App {
    private let modelContainer: ModelContainer
    @State private var coordinator: AppCoordinator

    init() {
        do {
            let container = try DataLayer.makeModelContainer()
            try CurriculumSeeder.seedIfNeeded(in: container.mainContext)
            self.modelContainer = container
            self._coordinator = State(initialValue: AppCoordinator(modelContext: container.mainContext))
        } catch {
            fatalError("Failed to configure SwiftData persistence: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView(coordinator: coordinator)
        }
        .modelContainer(modelContainer)
    }
}
#endif
