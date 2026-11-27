# 🤖 Agent Rules — English Mastery iOS

## Technology Stack
- **Language:** Swift 6 (strict concurrency)
- **UI:** SwiftUI (iOS 17+)
- **Persistence:** SwiftData
- **Architecture:** MVVM (Model-View-ViewModel)
- **Minimum target:** iOS 17.0

## Code Conventions
- Use `@Observable` macro instead of `ObservableObject`
- Prefer `async/await` over callbacks and Combine
- Data models with `@Model` from SwiftData
- Small and composable views; extract subviews when exceeding ~50 lines
- File names = name of the main type they contain
- Unit tests for all domain logic and RAG pipeline

## Folder Architecture
- `Sources/App/` → Entry point and app configuration
- `Sources/Domain/` → Pure entities, use cases, RAG pipeline protocol
- `Sources/Data/` → SwiftData implementations, PDFKit parser, VectorStore, LLM engine
- `Sources/Presentation/` → SwiftUI Views and ViewModels

## Source of Truth
- All design decisions must align with the documents in `/specs`
- Before generating code, consult the relevant spec
