import SwiftUI
import SwiftData

@main
struct EnglishMasteryApp: App {
    private let modelContainer: ModelContainer

    init() {
        do {
            let container = try DataLayer.makeModelContainer()
            try CurriculumSeeder.seedIfNeeded(in: container.mainContext)
            self.modelContainer = container
        } catch {
            fatalError("Failed to configure SwiftData persistence: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(modelContainer)
    }
}

struct ContentView: View {
    var body: some View {
        Text("English Mastery")
            .font(.largeTitle)
            .fontWeight(.bold)
    }
}
