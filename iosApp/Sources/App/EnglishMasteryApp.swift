// EnglishMasteryApp.swift
// Application entry point

import SwiftUI
import SwiftData

@main
struct EnglishMasteryApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        // TODO (Milestone 1): Attach .modelContainer(for: [...]) once SwiftData @Model entities are added
    }
}

struct ContentView: View {
    var body: some View {
        Text("English Mastery")
            .font(.largeTitle)
            .fontWeight(.bold)
    }
}
