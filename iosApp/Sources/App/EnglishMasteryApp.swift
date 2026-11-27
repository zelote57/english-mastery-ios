import SwiftUI
import SwiftData

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
