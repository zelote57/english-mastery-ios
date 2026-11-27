---
name: ios-unit-testing
description: >-
  Designs and writes deterministic XCTest suites for Swift 6 strict concurrency,
  in-memory SwiftData @Model persistence, Domain progression/Levenshtein
  engines, and protocol-mocked RAG pipelines in iosApp/Tests/. Use when
  implementing Milestone 1/3/4 unit tests or adding regression coverage.
---

# iOS Unit Testing Workflow (`XCTest` / Swift 6 / SwiftData)

Operational manual for writing deterministic, zero-flakiness unit tests in `iosApp/Tests/` targeting Xcode 16+, Swift 6 strict concurrency, and iOS 17.0+.

## Reference Files (Progressive Disclosure)

Consult these files before writing or updating tests:
- [AGENTS.md](../../../AGENTS.md) — Test requirements for all domain logic and RAG pipeline.
- [01-cambridge-phases.md](../../../specs/01-cambridge-phases.md) — Thresholds (`>= 0.80`), phase progression, infinite repetition, and Drill Score Isolation invariants.
- [02-curriculum-skills.md](../../../specs/02-curriculum-skills.md) — `questionType` grading matrix and deterministic Levenshtein partial-credit rules.
- [03-rag-architecture.md](../../../specs/03-rag-architecture.md) — Chunker (~300 tokens), Top-3 cosine retrieval, Spanish output template, and fallback contract.
- [04-data-models.json](../../../specs/04-data-models.json) — Canonical schema contracts.
- [RAGPipelineTests.swift](../../../iosApp/Tests/RAGPipelineTests.swift) — Existing RAG and native embedding tests.
- [Project.yml](../../../iosApp/Project.yml) — `EnglishMasteryTests` bundle configuration.

## Step-by-Step Testing Procedure

### 1. Framework & Target Structure
- Use **`XCTest`** (`import XCTest`, `@testable import EnglishMastery`) matching existing tests and CI (`xcodebuild test` in `.github/workflows/ios-build.yml`).
- Organize test files by feature/domain component under `iosApp/Tests/` (all files inside `Tests/` are auto-included by `iosApp/Project.yml`), e.g.:
  - `ScoringEngineTests.swift` (Levenshtein partial credit, normalization, `multipleChoice` vs `fillBlank`)
  - `ProgressionEngineTests.swift` (onboarding, 18-Q placement, monotonic `bestScore`, 9-phase unlocking)
  - `MistakeDrillIsolationTests.swift` (strict isolation invariants)
  - `SwiftDataPersistenceTests.swift` (in-memory container, relationships, seeding counts)
  - `RAGPipelineTests.swift` (chunking, cosine search, prompt assembly, fallback card)

### 2. In-Memory SwiftData Testing Pattern (iOS 17+ / Swift 6)
For persistence, seeding, and ViewModel/Repository integration tests, create an isolated ephemeral container per test method—never touch on-disk storage or share state across tests:

```swift
import XCTest
import SwiftData
@testable import EnglishMastery

@MainActor
final class SwiftDataPersistenceTests: XCTestCase {
    private func makeInMemoryContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(
            for: UserModel.self, PhaseModel.self, SkillModel.self, QuestionModel.self, AttemptModel.self, AnswerRecordModel.self,
            configurations: config
        )
    }

    func testSeedIntegrity() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        // Run deterministic seeder and assert counts (9 phases, 29 skills, >15 Qs/skill, 18 placement)
    }
}
```
- Annotate SwiftUI ViewModel / `mainContext` test classes or methods with `@MainActor` so Swift 6 strict concurrency compiles cleanly without `@unchecked Sendable` hacks.
- Pure `Domain` tests (`ScoringEngine`, `EvaluateAttemptUseCase`) should NOT import `SwiftData` and can run without `@MainActor` using synchronous or `async throws` test methods.

### 3. Protocol Fakes for the Local RAG & LLM Pipeline
Never use network or real LLM weights in tests. Use `EmbeddingProvider` fakes for deterministic ranking tests; separately retain native `NLEmbedding` integration and relevance tests against the bundled corpus.
For future LLM integration, create a test double at the real inference boundary:
- `MockLLMEngine`:
  - Happy path: returns a valid 3-heading Spanish Markdown card (`< 150` words) and captures the assembled prompt to assert `{level}`, `{user_answer}`, `{correct_answer}`, `{rag_chunks}`, and Spanish output instruction were injected.
  - Failure / timeout path: throws an error to prove the feedback use case returns a valid 3-heading Spanish fallback card without crashing or leaving `AnswerRecord.ragFeedback` blank.

### 4. Mandatory Edge-Case Matrix
Every Domain & RAG test suite MUST cover these exact boundary cases:

| Area | Required Edge Cases |
|:--|:--|
| **Mastery Threshold** | `0.79` (`11.5 / 15.0` or `11.0 / 15.0`) -> `isPassed == false`; `0.80` (`12.0 / 15.0` via 12×`+1.0` OR 11×`+1.0` + 2×`+0.5`) -> `isPassed == true` |
| **Levenshtein Partial Credit** | Exact & `acceptedSynonyms` (case/whitespace/apostrophe variations) -> `+1.0` (`isCorrect == true`); `fillBlank`/`translation` edit distance `1` on `< 5`-char word -> `+0.5`, distance `2` on `< 5`-char word -> `0.0`; distance `2` on `>= 5`-char word -> `+0.5`, distance `3` -> `0.0`; `multipleChoice`/`reorder` close string -> `0.0` (never `+0.5`) |
| **Attempt Counters** | `correctAnswers` counts ONLY `+1.0` items; `earnedPoints` sums `+1.0` and `+0.5`; `score == earnedPoints / Double(totalQuestions)` |
| **Placement Routing** | Start from Scratch -> `A1` `available`, `2...9` `locked`; Sequential threshold (`>= 1.5 / 2.0`): Place at Phase `1` (`A1`) -> `0` skipped phases; First block `< 1.5` stops advancement even if later blocks pass (`1...K-1` `skippedPassed`, `K` `available`, `K+1...9` `locked`); Perfect `18/18` places at Phase `9` (`B2_ADV`) `available` with `1...8` `skippedPassed` |
| **Infinite Repetition & Phase Unlock** | Retaking passed skill with `0.40` preserves `isPassed == true` and higher `bestScore`; `N - 1` passed skills leaves `currentPhaseId` unchanged; passing skill `N` marks `activePhase` `completed` and advances; completing Phase `9` marks Phase `9` `completed` cleanly without overflow; completing a `skippedPassed` phase skill never mutates `user.currentPhaseId` |
| **Drill Score Isolation** | Completing `MistakeDrillView` / `MistakeDrillUseCase` leaves `Attempt` count, `Attempt.score`, `Skill.bestScore`, `Skill.isPassed`, `user.currentPhaseId`, `user.streakDays`, and 5-attempt trend identical |
| **Streak & History** | Last 5 `skillAssessment` attempts sorted chronologically (`placementTest` excluded from skill history); calendar-day streak increments on next day, stays flat on same day, resets after missed day |
| **Seed Data Invariants** | `9` phases, `29` unique `skillCode`s, every skill has `> 15` questions, `18` `isPlacementEligible == true` (`2` per phase), zero `correctAnswer` duplicated inside `distractors` |
| **RAG Pipeline** | Chunk sizes stay near ~300 tokens with preserved `level` (`A1`…`B2_ADV`), `topic`, `chunkIndex`; Top-3 cosine ranking order; `< 150` word Spanish fallback on LLM failure |

## Verification Before Pushing
- Inject `Date` / randomizer abstractions (`() -> Date`, `SystemRandomNumberGenerator` vs seeded RNG) into use cases so tests never depend on wall-clock timing (`sleep`) or flaky randomness.
- Ensure every test file compiles cleanly under Swift 6 strict concurrency (`Sendable` closures/fakes, `@MainActor` where SwiftData `mainContext` is used).

## Gotchas (Strict Constraints)
- **No Wall-Clock Sleeps or Network Calls:** Tests must run offline in milliseconds on the GitHub Actions macOS simulator runner (`iOS Build & Test`). Never use `Thread.sleep` or arbitrary `Task.sleep` timings to synchronize async work; `await` structured tasks directly.
- **Keep Domain Tests Free of SwiftData:** Test pure rules against `Domain` types directly, and keep `ModelContainer(isStoredInMemoryOnly: true)` inside dedicated persistence/integration tests.
- **Keep Test Helpers Local:** Put small helper builders inside each test file rather than building fragile shared mutable global state across test suites.
