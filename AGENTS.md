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

## Conciseness & Anti-Overengineering
- **YAGNI strictly:** Implement only what the active `/specs` requirement and current milestone require; no speculative flags, future-proofing extension points, or dead code
- **No ceremonial abstractions:** Define a `protocol` only at real polymorphism or test-double boundaries (`RAGPipeline`, `LLMEngine`, `VectorStore`); never create single-implementation `Protocol` + `Impl` pairs, pass-through wrappers, or redundant DTO/mappers
- **Prefer Swift & platform primitives:** Use value types (`struct`, `enum`), `throws`, standard library algorithms, and SwiftUI/SwiftData built-ins (`@Query`, `@Observable`) before writing custom helpers or base classes
- **Keep code direct and minimal:** Write short functions with early `guard` returns; reuse shared helpers instead of duplicating logic, and avoid creating separate files for trivial helpers (a new file is for a distinct reusable type or extracted `> ~50`-line subview)
- **Self-prune before finishing:** Review your diff and inline or remove any layer, type, or indirection that adds ceremony without improving Swift 6 safety, testability, or clarity

## Folder Architecture
- `Sources/App/` → Entry point and app configuration
- `Sources/Domain/` → Pure entities, use cases, RAG pipeline protocol
- `Sources/Data/` → SwiftData implementations, PDFKit parser, VectorStore, LLM engine
- `Sources/Presentation/` → SwiftUI Views and ViewModels

## Source of Truth
- All design decisions must align with the documents in `/specs`
- Before generating code, consult the relevant spec
