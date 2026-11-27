---
name: cambridge-ios-progression
description: >-
  Implements and validates the 9-phase CEFR/Cambridge progression engine (`A1`
  to `B2_ADV`), onboarding & 18-question placement test (`SKIPPED_PASSED`),
  15-question skill assessments with `+1.0`/`+0.5`/`0.0` scoring, post-test
  mistake drills (`Practice Missed Questions`), SwiftData persistence, and
  XCTest unit tests in Swift 6. Use when building onboarding routing, phase
  unlocking, test scoring, attempt persistence, or progression tests.
---

# Cambridge iOS Progression & Evaluation Workflow

Operational manual for implementing and verifying the 9-phase Cambridge CEFR
progression engine, placement routing, test grading, isolated mistake drills,
and SwiftData/Domain models in `iosApp/`.

## Reference Specs (Progressive Disclosure)

Consult these specs before modifying or generating code:
- [01-cambridge-phases.md](../../../specs/01-cambridge-phases.md) — 9-phase matrix (`A1` to `B2_ADV`), Cambridge exam alignment, onboarding/placement rules, `>= 0.80` threshold, and drill score isolation.
- [02-curriculum-skills.md](../../../specs/02-curriculum-skills.md) — 29 skill codes across the 9 phases, curriculum topics, and `+1.0` / `+0.5` / `0.0` scoring rubrics by `questionType`.
- [04-data-models.json](../../../specs/04-data-models.json) — Canonical schemas for `User`, `Phase`, `Skill`, `Question`, `Attempt`, and `AnswerRecord`.
- [05-ui-flows.md](../../../specs/05-ui-flows.md) — UI flows and `AppState` (`ModelGateView`, `OnboardingView`, `PlacementTestView`, `HomeView`, `SkillDetailView`, `TestView`, `FeedbackView`, `MistakeDrillView`).
- [06-roadmap-milestones.md](../../../specs/06-roadmap-milestones.md) — Phased implementation milestones (M0–M5), seed counts, and test priorities.
- [AGENTS.md](../../../AGENTS.md) — Swift 6 strict concurrency, SwiftUI, SwiftData, and MVVM conventions.

## Architecture Boundaries (Swift 6 Strict Concurrency)

- **`iosApp/Sources/Domain/`**: Pure Swift business entities, `Sendable` domain structs/protocols, grading evaluators, and use cases (`PlacementEvaluationUseCase`, `EvaluateAttemptUseCase`, `MistakeDrillUseCase`). Keep free of `SwiftUI` and `SwiftData` imports.
- **`iosApp/Sources/Data/`**: `@Model` SwiftData classes, `ModelContainer` setup, seeding (9 phases, 29 skills, `>15` questions/skill, 18 placement-eligible questions), and repository implementations.
- **`iosApp/Sources/Presentation/`**: `@Observable` ViewModels (`@MainActor`) and small, composable SwiftUI views.
- **`iosApp/Tests/`**: Deterministic `XCTest` unit tests covering every progression, grading, placement, and isolation invariant.

## Step-by-Step Implementation Procedure

### 1. Onboarding & 18-Question Placement Test Routing
1. Ensure initial app seeding creates a default local `User` (`name: "Learner"`, `hasCompletedOnboarding: false`) alongside the 9 phases and 29 skills.
2. After `ModelGateView` loads the curriculum, check `user.hasCompletedOnboarding`. Model-weight provisioning is planned for Milestone 4 and is not currently implemented.
3. If `false`, route to `OnboardingView` presenting two English choices:
   - **"Start from Scratch"**: Marks Phase 1 (`A1`) as `available`, Phases 2–9 as `locked`, sets `user.currentPhaseId` to Phase 1, and sets `user.hasCompletedOnboarding = true`.
   - **"Take Placement Test"**: Launches `PlacementTestView` serving **18 diagnostic questions** (2 `isPlacementEligible` questions per phase from `A1` to `B2_ADV`, run in diagnostic mode without mid-test RAG interruption).
4. **Determine Target Phase $K$:** Evaluate each phase block `1...9` sequentially from `A1`. A phase block passes placement if `phaseEarnedPoints >= 1.5` (out of `2.0`). Set $K$ to the **first** phase scoring `< 1.5`, or `9` (`B2_ADV`) if all 9 phases clear `>= 1.5`.
5. Route placement outcome at Phase $K$:
   - Mark Phases $1 \dots K-1$ as `skippedPassed` (`SKIPPED_PASSED`, unlocked for optional practice without blocking or gating progression).
   - Mark Phase $K$ as `available`, set `user.currentPhaseId` to Phase $K$'s `id`, and store `user.placementPhaseCode`.
   - Keep Phases $K+1 \dots 9$ as `locked`, and set `user.hasCompletedOnboarding = true`.
6. Derive each skill/phase visual state in `HomeView`:
   - **Passed (`✅`)**: `skill.isPassed == true` (`bestScore >= 0.80`).
   - **Skipped Passed (`⏭️`)**: Belongs to a phase marked `skippedPassed` (`1...K-1` after Placement Test) and not yet passed by skill test; unlocked for optional practice.
   - **Available (`🔵`)**: Belongs to the active phase (`user.currentPhaseId`) or a `completed` phase.
   - **Locked (`🔒`)**: Belongs to a phase ahead of `user.currentPhaseId`.

### 2. Test Execution & Anti-Memorization (15 Questions)
1. Serve **15 questions** per official skill assessment.
2. Shuffle question order and randomize `distractors` positions on every attempt.
3. Apply two-tier anti-memorization across retakes:
   - **P0 (Curated Bank — Always Required):** Seed `>15` questions per skill and sample 15 per attempt prioritizing unseen or previously missed questions.
   - **P1+ (RAG-Assisted Variation):** When the local `VectorStore` (`/knowledge-base/`) and LLM are active, optionally vary sentence contexts and distractors using retrieved grammar chunks while validating against deterministic answer keys.
4. **Immediate Error Interruption:** When a question scores `0.0` during a skill assessment in `TestView`, pause progression immediately and invoke `duolingo-rag-tutor` to show the Spanish feedback sheet until the user taps `"Continue"`.

### 3. Grading, Scoring & Phase Advancement Logic
Implement grading cleanly in a pure Domain evaluator:
1. Normalize free-text responses (trim leading/trailing whitespace; handle expected case sensitivity and `Question.acceptedSynonyms`).
2. Score each `Question` according to `specs/02-curriculum-skills.md` and `questionType`:
   - `multipleChoice` & `reorder`: Binary grading (`+1.0` exact match or `0.0` incorrect).
   - `fillBlank` & `translation`:
     - **Correct (`+1.0` pt):** Exact answer or `acceptedSynonyms` (`isCorrect = true`).
     - **Partial (`+0.5` pt):** Valid grammatical structure with a minor spelling/typography slip (`isCorrect = false`; surface a non-blocking spelling hint).
     - **Incorrect (`0.0` pt):** Grammatical, structural, vocabulary, or Spanish-interference error (`isCorrect = false`; triggers immediate RAG sheet and queues for mistake drill).
3. Compute normalized attempt score in `0.0...1.0`:
   ```swift
   let score = totalQuestions > 0 ? earnedPoints / Double(totalQuestions) : 0.0
   ```
4. Persist an official `Attempt` (`attemptType: .skillAssessment`, `timestamp`, `score`, `earnedPoints`, `totalQuestions`, `correctAnswers` counting `+1.0` answers, and linked `[AnswerRecord]` entries with `pointsEarned` and `ragFeedback`).
5. Evaluate mastery and phase unlocking immediately after saving the `Attempt`:
   ```swift
   skill.bestScore = max(skill.bestScore, attempt.score)

   if skill.bestScore >= 0.80 {
       skill.isPassed = true
   }

   if skill.phaseId == user.currentPhaseId,
      activePhase.skills.allSatisfy(\.isPassed) {
       activePhase.status = .completed
       if let nextPhase = orderedPhases.next(after: activePhase) {
           nextPhase.status = .available
           user.currentPhaseId = nextPhase.id
       }
   }
   ```
6. Enforce **infinite repetition**: never block retakes on passed or failed skills, and never revoke `isPassed` or lower `bestScore` if a subsequent attempt scores below `0.80`.
7. Update `SkillDetailView` metrics (`bestScore`, total official attempts count, chronological **last 5 attempts** trend) and update `user.streakDays` using calendar-day comparison against `user.lastPracticeDate`.

### 4. Post-Test Mistake Drill (`Practice Missed Questions`)
1. Display the official `Attempt.score` immediately in `FeedbackView` upon completing all 15 questions (with confetti animation if `score >= 0.80`).
2. Collect `failedQuestions` from `AnswerRecord` entries where `pointsEarned == 0.0`.
3. If `failedQuestions.isEmpty == false`, display a **"Practice Missed Questions"** button.
4. Launching `MistakeDrillView` presents **only the missed questions** (or fresh RAG variations testing the same grammar rule) in a loop until answered correctly.

### 5. Unit Testing & Validation (`iosApp/Tests/`)
Write deterministic `XCTest` unit tests covering every progression invariant:
- **Placement routing:** Start from Scratch sets `A1`; Placement Test evaluates blocks sequentially (`>= 1.5 / 2.0`), stops at the first `< 1.5` block (even if higher phases succeed by chance), marks `1...K-1` as `skippedPassed`, sets `K` as `available`, keeps `K+1...9` `locked`, and handles boundary placements at Phase 1 (`A1`) and Phase 9 (`B2_ADV` including `18/18` perfect score).
- **Threshold boundary:** `0.79` (`11.5 / 15.0`) fails (`isPassed == false`); `0.80` (`12.0 / 15.0`) passes (`isPassed == true`).
- **Partial credit & questionType:** Verify `+0.5` applies to `fillBlank`/`translation` typos, updates `earnedPoints` and `score` accurately without inflating `correctAnswers`, and never applies to `multipleChoice`/`reorder`.
- **Infinite repetition:** Retaking a passed skill with `0.40` preserves `isPassed == true` and the higher `bestScore`.
- **Phase unlocking:** Passing `N - 1` skills keeps `user.currentPhaseId` unchanged; passing the `N`-th skill marks `activePhase` `completed` and advances to the next of the 9 phases; completing Phase 9 (`B2_ADV`) marks Phase 9 `completed` without overflow; practicing/passing a skill in an earlier `skippedPassed` phase does not move `user.currentPhaseId`.
- **Drill Score Isolation:** Running a full `"Practice Missed Questions"` drill leaves `Attempt` count, `Attempt.score`, `Skill.bestScore`, `Skill.isPassed`, `user.currentPhaseId`, and 5-attempt trend completely untouched.
- **Attempt history & streak:** Verify chronological ordering, 5-attempt slicing, and `streakDays` increments/resets via `lastPracticeDate`.

On macOS CI/local environments, verify with:
```bash
xcodebuild test -project iosApp/EnglishMastery.xcodeproj -scheme EnglishMastery -destination 'platform=iOS Simulator,name=iPhone 15,OS=latest'
```

## Gotchas (Strict Constraints)
- **Drill Score Isolation:** Completing `"Practice Missed Questions"` updates ephemeral learning reinforcement only; it **MUST NEVER** create an official `Attempt`, overwrite `Attempt.score` or `Skill.bestScore`, or unlock a skill/phase. A full 15-question official retake is mandatory to pass a failed skill.
- **100% Offline Execution:** Never import cloud AI SDKs or make network calls during tests, grading, or RAG retrieval (network is permitted solely for initial model weight download in `ModelGateView`). All runtime execution must run locally on iPhone 13 (A15 Bionic) or newer (`iOS 17.0+`).
- **Strict Language Separation:** All SwiftUI controls, navigation titles, buttons (including `"Start from Scratch"`, `"Take Placement Test"`, `"Start Test"`, `"Continue"`, `"Practice Missed Questions"`), and test prompts MUST be in **English**. Pedagogical error feedback MUST be generated in **Spanish** (delegated to `duolingo-rag-tutor`).
