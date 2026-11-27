---
name: ios-swiftui-mvvm
description: >-
  Builds SwiftUI iOS 17+ views, @Observable @MainActor ViewModels, AppState
  navigation routing, subview extraction (~50 lines), EN/ES strict language
  separation, dark mode, and accessibility in Swift 6 strict concurrency. Use
  when implementing ModelGateView, OnboardingView, PlacementTestView, HomeView,
  SkillDetailView, TestView, FeedbackView, MistakeDrillView, or UI components.
---

# SwiftUI & MVVM Implementation Workflow (iOS 17+ / Swift 6)

Operational manual for building the Presentation layer (`iosApp/Sources/Presentation/`) aligned with Swift 6 strict concurrency, Apple HIG, and the project's 8-view navigation flow.

## Reference Specs (Progressive Disclosure)

Consult these files before creating or editing any view or ViewModel:
- [05-ui-flows.md](../../../specs/05-ui-flows.md) — Complete navigation map, all 8 views, `AppState` enum, and language separation rule.
- [01-cambridge-phases.md](../../../specs/01-cambridge-phases.md) — 9-phase curriculum metadata (`A1` to `B2_ADV`) and 4 skill/phase UI states.
- [02-curriculum-skills.md](../../../specs/02-curriculum-skills.md) — Question types (`multipleChoice`, `fillBlank`, `translation`, `reorder`) and partial-credit UX behavior.
- [04-data-models.json](../../../specs/04-data-models.json) — Canonical fields for `User`, `Phase`, `Skill`, `Question`, `Attempt`, and `AnswerRecord`.
- [06-roadmap-milestones.md](../../../specs/06-roadmap-milestones.md) — Milestone 2 (UI without RAG) and Milestone 5 (polish, Dark Mode, accessibility).
- [AGENTS.md](../../../AGENTS.md) — `@Observable`, `async/await`, subview extraction, and file naming rules.
- [hig-ux-checklist.md](./references/hig-ux-checklist.md) — Apple HIG (`44×44pt`, `4/8pt` grid), Duolingo-inspired UX (`sensoryFeedback`, input settings, Mobbin benchmarking), VoiceOver, and Swift 6 UI concurrency rules.

## Architecture & Swift 6 Concurrency Boundaries

- **Presentation Location:** Place all Views and ViewModels under `iosApp/Sources/Presentation/` (auto-scanned by `iosApp/Project.yml`). Name every file after its primary type (e.g., `HomeView.swift`, `HomeViewModel.swift`).
- **ViewModels:** Annotate ViewModels with `@Observable` and `@MainActor`. Never use legacy `ObservableObject`, `@Published`, `@ObservedObject`, `@StateObject`, or Combine pipelines.
- **View Purity:** Keep SwiftUI `View` bodies strictly declarative and under **~50 lines**. When a view grows larger, extract focused subviews (e.g., `PhaseSectionView.swift`, `QuestionPromptCard.swift`).
- **Zero Business Logic in Views:** Never perform Levenshtein grading, phase unlocking, `Attempt` creation, or RAG retrieval inside SwiftUI Views; delegate through ViewModels to `Domain` use cases via `async/await`.
- **SwiftData Boundary:** Keep `@Model` mutations isolated cleanly; pass `Sendable` Domain structs across `Task` / `actor` boundaries.

## Step-by-Step UI Implementation Procedure

### 1. Root Router & `AppState` Machine
Implement an `@Observable @MainActor` root coordinator driving all 7 `AppState` cases from `05-ui-flows.md`:
1. `.gatingModel` → `ModelGateView` (`loading`, `downloading(progress)`, `ready`, `error`). In Milestone 0–2 placeholder mode, allow fast transition to `.ready` without real downloads while keeping the state contract intact for Milestone 4.
2. `.onboarding` → `OnboardingView` (shown only when `!user.hasCompletedOnboarding`), offering:
   - `"Start from Scratch"` → sets Phase 1 (`A1`) `available`, Phases 2–9 `locked`, routes to `.home`.
   - `"Take Placement Test"` → routes to `.placementTest`.
3. `.placementTest` → `PlacementTestView` serving 18 diagnostic questions (2 `isPlacementEligible` per phase) **without** mid-test RAG feedback sheets. On completion at Phase $K$, sets Phases `1...K-1` to `skippedPassed`, Phase $K$ to `available`, `K+1...9` to `locked`, sets `hasCompletedOnboarding = true`, and routes to `.home`.
4. `.home` → `HomeView` showing user streak (`streakDays`), active phase (`1...9`), overall progress bar, and the 9-phase skill list with all 4 distinct visual states:
   - `passed` (`✅`): `skill.isPassed == true` (`bestScore >= 0.80`)
   - `skippedPassed` (`⏭️`): Phases `1...K-1` unlocked via placement for optional practice
   - `available` (`🔵`): Active `currentPhaseId` or `completed` phase skill
   - `locked` (`🔒`): Phase ahead of `user.currentPhaseId` (tapping disabled or shows locked indicator)
5. `SkillDetailView` (navigation push from `HomeView`) → displays `skillCode`, `topic`, `bestScore`, official `skillAssessment` count, chronological trend chart of the **last 5 official attempts**, and `"Start Test"` button routing to `.testInProgress`.
6. `.testInProgress` → `TestView` (`Question X of 15`).
7. `.reviewingFeedback` → `FeedbackView` (with optional `.mistakeDrill` → `MistakeDrillView`).

### 2. Interactive `TestView` & Input Modes
Render question UI cleanly per `Question.questionType`:
- `multipleChoice`: Present shuffled options (`[correctAnswer] + distractors` shuffled once per question render, never re-shuffled on SwiftUI re-evaluation).
- `fillBlank` & `translation`: Provide a clean English text input field with autocorrection disabled (`.autocorrectionDisabled(true)` and `.textInputAutocapitalization(.never)` where appropriate so iOS does not auto-fix learner grammar mistakes).
- `reorder`: Interactive word-token tap chips allowing construction and undo of the target English sentence.

Immediate post-submission feedback handling:
- **`pointsEarned == 1.0`:** Briefly highlight success and advance.
- **`pointsEarned == 0.5` (`fillBlank` / `translation`):** Show a non-blocking spelling hint revealing the exact `correctAnswer` spelling before advancing.
- **`pointsEarned == 0.0`:** Pause test progression immediately and present a sheet with a non-blocking thinking/streaming state (or deterministic 3-heading Spanish fallback card in Milestone 2) displaying:
  - `### 💡 ¿Por qué no es correcta?`
  - `### 📘 Regla clave`
  - `### 🔍 Ejemplos prácticos`
  Require an explicit tap on the English **`"Continue"`** button (`interactiveDismissDisabled(true)`) before advancing and persisting `ragFeedback` to `AnswerRecord`.

### 3. `FeedbackView` & Isolated `MistakeDrillView`
- `FeedbackView`: Show the normalized official `Attempt.score` (e.g., `"80%"`), trigger a celebratory confetti animation when `score >= 0.80`, list missed questions as expandable cards reading `AnswerRecord.ragFeedback`, and provide `"Retry Test"`, `"Back to Home"`, `"Next Skill"`.
- Show **"Practice Missed Questions"** button **only** when `failedQuestions` (`pointsEarned == 0.0`) is non-empty.
- `MistakeDrillView`: Loop missed questions until each is answered correctly, then return cleanly without calling `EvaluateAttemptUseCase` or modifying SwiftData `Attempt`, `Skill`, or `Phase` records.

### 4. Dark Mode, Dynamic Type & Accessibility (Milestone 5)
- Use semantic system colors (`Color(.systemBackground)`, `Color(.secondarySystemBackground)`, `.primary`, `.secondary`) and verify contrast for all 4 skill badges (`✅`, `⏭️`, `🔵`, `🔒`) in both Light and Dark Mode.
- Avoid fixed heights on text containers; allow multiline wrapping and Dynamic Type scaling.
- Provide clear English `accessibilityLabel` and `accessibilityHint` values for custom status badges, progress indicators, and reorder token chips.

## Verification Before Pushing
- Inspect view sizes (`< ~50` lines per `View` body; extract subviews cleanly).
- Verify all `ViewModel` classes are `@Observable @MainActor` and contain zero `Combine` / `ObservableObject` references.
- Verify no English/Spanish leakage across UI chrome vs feedback content.
- Run through [hig-ux-checklist.md](./references/hig-ux-checklist.md) (`44×44pt` targets, `4/8pt` spacing, `.sensoryFeedback`, `.task(id:)`, `@Bindable`, Dark Mode, and VoiceOver).

## Gotchas (Strict Constraints)
- **Strict Language Separation:** ALL SwiftUI titles, labels, status badges, buttons (`"Start from Scratch"`, `"Take Placement Test"`, `"Start Test"`, `"Continue"`, `"Practice Missed Questions"`, `"Retry Test"`, `"Back to Home"`, `"Next Skill"`), and question prompts MUST be in **English**. Only the error explanation sheets and `FeedbackView` error cards are written in **Spanish** (with English example sentences).
- **Never Block `@MainActor`:** Show a thinking indicator or stream tokens asynchronously when `TestView` triggers RAG/LLM explanation; never freeze touch input.
- **No Shuffling Bug on State Updates:** Shuffle `distractors` and questions once inside the `ViewModel` when loading the test/question — never shuffle inside a SwiftUI `View.body` computed property.
- **Never Leak Drill State:** `MistakeDrillView` UI completion must never create or mutate official SwiftData records.
