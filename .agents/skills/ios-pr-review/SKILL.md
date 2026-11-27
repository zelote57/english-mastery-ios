---
name: ios-pr-review
description: >-
  Performs evidence-based Pull Request and local diff reviews tailored to
  English Mastery iOS. Verifies spec alignment, Drill Score Isolation, EN/ES
  language lock, Swift 6 strict concurrency, SwiftUI subview limits, offline
  guarantees, test coverage, and security using git diff and GitHub MCP tools.
  Use when reviewing a PR, auditing changes before merging, or running a
  pre-commit code review.
---

# English Mastery iOS — Pull Request & Diff Review Workflow

Structured code review rubric tailored to this repository's Swift 6 / SwiftUI / SwiftData architecture, Cambridge progression invariants, and on-device RAG constraints.

## Reference Specs (Progressive Disclosure)

Consult the relevant spec before judging domain or UI logic in a diff:
- [AGENTS.md](../../../AGENTS.md) — Swift 6 strict concurrency, MVVM, `@Observable`, subview size (~50 lines), file naming, and anti-overengineering rules.
- [01-cambridge-phases.md](../../../specs/01-cambridge-phases.md) — 9 phases (`A1`…`B2_ADV`), `>= 0.80` mastery threshold, monotonic `bestScore`, `skippedPassed`, and Drill Score Isolation.
- [02-curriculum-skills.md](../../../specs/02-curriculum-skills.md) — 29 skills and deterministic binary grading.
- [03-rag-architecture.md](../../../specs/03-rag-architecture.md) — 100% on-device execution, ~300-token chunking, Top-3 cosine retrieval, grounded Spanish prompts.
- [04-data-models.json](../../../specs/04-data-models.json) — Canonical schemas, types, and enums for all 7 models.
- [05-ui-flows.md](../../../specs/05-ui-flows.md) — 8 views, 7 `AppState` cases, and strict EN/ES language separation.
- [Project.yml](../../../iosApp/Project.yml) — Target scanning and Swift 6 build settings.
- [ios-build.yml](../../../.github/workflows/ios-build.yml) — Remote macOS CI workflow checks.

## Step-by-Step Review Procedure

### 1. Gather the Diff & Context
- **Local diff / pre-PR:** Run `git status` and `git diff` (or inspect changed files directly if git is not yet initialized).
- **GitHub Pull Request:** Use the `github` MCP (`list_pull_requests`, `pull_request_read`, `list_commits`, `get_commit`) to inspect every changed file, commit message, and remote CI check result from `iOS Build & Test`.
- Read complete surrounding functions/types of modified code rather than guessing from diff hunks alone.

### 2. Five-Axis Review Rubric

#### Axis A — Domain & Spec Invariants (`Blocker` if violated)
- **9-Phase & 29-Skill Alignment:** Enum raw values and state names match `04-data-models.json` (`A1`…`B2_ADV`, `skippedPassed`, `skillAssessment`, `placementTest`).
- **Scoring & Mastery Rules:**
  - New answers score `1.0` for a normalized accepted match and `0.0` otherwise, including spelling errors; historical partial-credit scores remain unchanged.
  - `Attempt.correctAnswers` counts only `+1.0` full answers; `bestScore` is monotonic and never revokes `isPassed`.
- **Drill Score Isolation:** `MistakeDrillView` / `MistakeDrillUseCase` MUST NEVER create an `Attempt`, alter `Attempt.score`, `Skill.bestScore`, `Skill.isPassed`, `user.streakDays`, or unlock any phase.
- **Placement Isolation:** `PlacementTestView` serves 18 `isPlacementEligible` questions without mid-test RAG interruption sheets.
- **100% Offline Guarantee:** Zero cloud AI SDK imports or runtime network calls outside `ModelGateView` local weight provisioning.
- **Strict Language Separation:** All SwiftUI labels, titles, buttons (`"Continue"`, `"Start Test"`, `"Practice Missed Questions"`), and question prompts are in **English**; pedagogical error explanations (3-heading Markdown template, `< 150` words) are in **Spanish** with English examples.

#### Axis B — Architecture & Swift 6 Strict Concurrency (`Blocker` / `Major`)
- **Layer Boundaries:** `Sources/Domain/` imports ONLY `Foundation` (no `SwiftUI`, `SwiftData`, `Combine`, or UI/data frameworks).
- **Concurrency Safety:**
  - Types crossing async/actor boundaries (`Domain` models, `Chunk`, grading results) conform to `Sendable`.
  - ViewModels are annotated `@Observable @MainActor` (zero `ObservableObject`, `@Published`, `@StateObject`, or Combine).
  - Mutable shared services (`VectorStore`, `LLMEngine`, SwiftData background work) use `actor` / `@ModelActor`.
  - SwiftData `@Model` instances are never captured across non-isolated `Task` or `actor` boundaries.
- **UI & File Conventions:** SwiftUI `View` bodies stay under **~50 lines** (subviews extracted cleanly); filenames match their primary type; no business logic inside Views; `distractors`/questions are never re-shuffled inside `View.body`.

#### Axis C — Tests & Regression Coverage (`Major`)
- Any new or modified Domain logic, persistence flow, or RAG pipeline step includes deterministic `XCTest` coverage in `iosApp/Tests/` (in-memory SwiftData `ModelConfiguration(isStoredInMemoryOnly: true)` and protocol fakes).
- Check edge cases: `0.79` vs `0.80` pass threshold, spelling errors, Phase 1 and Phase 9 placement boundaries, empty/timeout LLM fallback returning the 3-heading Spanish card.

#### Axis D — Security & Project Hygiene (`Blocker`)
- Zero hardcoded tokens, GitHub PATs, API keys, `.env`, or `mcp_config.json` files anywhere in the diff.
- `iosApp/Project.yml` preserves `SWIFT_VERSION: "6.0"`, `SWIFT_STRICT_CONCURRENCY: complete`, `IPHONEOS_DEPLOYMENT_TARGET: "17.0"`, and `GENERATE_INFOPLIST_FILE: true` without manual `Info.plist` paths.

#### Axis E — Code Quality & Duplication (`Minor` / `Major`)
- Shared normalization/scoring helpers are reused rather than duplicated across `Skill` and `Placement` flows.
- No over-engineering: flag speculative single-implementation protocols, pass-through wrappers/DTOs, or custom utilities where Swift standard library / SwiftUI / SwiftData primitives suffice.
- No speculative unused files, dead code, commented-out blocks, or unrelated docstring deletions.

### 3. Output Format & GitHub Review Publishing
Present findings grouped by severity with exact file paths and line references:
- **Blockers:** Spec violations, concurrency errors, security leaks, isolation bugs (must fix before merge).
- **Majors:** Missing tests, wrong layer imports, oversized Views (`> ~50` lines), missing fallback handling.
- **Minors:** Naming, readability, optional simplifications.
- **Verification Summary:** Explicitly state which files were read, whether CI checks passed, and whether tests were verified remotely (`iOS Build & Test`) or only audited statically on Windows.

When posting back to an open GitHub PR (only if requested by the user), use `github` MCP `add_comment_to_pending_review` / `pull_request_review_write` with concise, actionable inline feedback referencing the exact rule violated.
