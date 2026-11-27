---
name: ios-remote-ci-verification
description: >-
  Runs pre-push Swift 6 strict concurrency, layer-isolation, and XcodeGen checks
  on Windows, verifies Apple/Swift APIs with apple-docs and context7 MCPs, and
  diagnoses remote macOS GitHub Actions build and XCTest results via GitHub
  tools. Use before committing/pushing Swift code or when debugging CI failures.
---

# iOS Remote CI & Swift 6 Verification Workflow

Operational manual for keeping `iosApp/` compiling cleanly on macOS CI (`Xcode 16+` / `Swift 6`) when developing locally on Windows without a local `xcodebuild` toolchain.

## Reference Files (Progressive Disclosure)

Consult these files during verification and CI triage:
- [Project.yml](../../../iosApp/Project.yml) — XcodeGen targets (`EnglishMastery`, `EnglishMasteryTests`), `SWIFT_VERSION: "6.0"`, `SWIFT_STRICT_CONCURRENCY: complete`, and `IPHONEOS_DEPLOYMENT_TARGET: "17.0"`.
- [ios-build.yml](../../../.github/workflows/ios-build.yml) — Remote CI pipeline (`macos-15`, XcodeGen generation, dynamic iOS 17+ simulator resolution, `build-for-testing`, `xcodebuild test`).
- [04-data-models.json](../../../specs/04-data-models.json) — Canonical property names, optionality, and enums to cross-check before pushing.
- [06-roadmap-milestones.md](../../../specs/06-roadmap-milestones.md) — Milestone targets and test scope.
- [AGENTS.md](../../../AGENTS.md) — Layer boundaries, naming rules, and technology constraints.

## Step-by-Step Verification Procedure

### 1. Pre-Push Static Audit (Local on Windows)
Because `xcodegen` and `xcodebuild` are unavailable on Windows, run these checks before every commit/push:

1. **File & XcodeGen Alignment (`iosApp/Project.yml`):**
   - Confirm every new Swift file resides under `iosApp/Sources/` (`App/`, `Domain/`, `Data/`, `Presentation/`) or `iosApp/Tests/`.
   - Confirm each filename exactly matches the main type inside it (`AGENTS.md`).
   - Confirm `Project.yml` keeps `GENERATE_INFOPLIST_FILE: true` (never re-add a manual `Sources/App/Info.plist` reference) and preserves `SWIFT_STRICT_CONCURRENCY: complete`.
2. **Domain Layer Purity:**
   - Scan `iosApp/Sources/Domain/` to ensure files import **only** `Foundation` (never `SwiftUI`, `SwiftData`, `Combine`, or cloud AI frameworks).
3. **Swift 6 Strict Concurrency Checklist:**
   - Every Domain struct/enum and DTO crossing async/actor boundaries conforms explicitly to `Sendable`.
   - ViewModels (`@Observable`) and UI routers carry `@MainActor`.
   - Shared mutable services (`VectorStore`, `LLMEngine`, embedding caches) use `actor` isolation.
   - SwiftData `@Model` objects are **never** passed across `Task` / `actor` boundaries; convert `@Model` records into `Sendable` Domain values on their owning actor/MainActor.
   - No unguarded global mutable `var`s or legacy `ObservableObject` / `@Published` usages.
4. **Spec Contract Check (`specs/04-data-models.json`):**
   - Verify enum raw values match canonically:
     - `Phase.level`: `A1`, `A2_INIT`, `A2_INT`, `A2_ADV`, `B1_INIT`, `B1_INT`, `B1_ADV`, `B2_INIT`, `B2_ADV`
     - `Phase.status`: `locked`, `available`, `completed`, `skippedPassed`
     - `Question.questionType`: `multipleChoice`, `fillBlank`, `translation`, `reorder`
     - `Attempt.attemptType`: `skillAssessment`, `placementTest`

### 2. Live API Signature Verification (MCPs)
Before pushing code that uses unfamiliar SwiftUI, SwiftData, PDFKit, NaturalLanguage (`NLEmbedding`), or MLX Swift APIs:
1. **Apple SDKs:** Query the `apple-docs` MCP (`search_apple_docs`, `search_framework_symbols`, `get_apple_doc_content`, `get_platform_compatibility`) to confirm exact iOS 17.0+ availability, macro arguments (`@Model`, `@Attribute`, `@Query`), and Swift 6 `Sendable` conformances.
2. **Third-Party Swift Packages:** Query the `context7` MCP (`resolve-library-id`, `query-docs`) for `MLX Swift` (`/ml-explore/mlx-swift`, `/ml-explore/mlx-swift-lm`) or `XcodeGen` syntax before editing `Project.yml` dependencies or Swift wrappers.

### 3. Remote CI Monitoring & Triage (GitHub)
After committing and pushing to GitHub:
1. Verify git repository and remote status (`git status`, `git remote -v`).
2. Check workflow runs for `.github/workflows/ios-build.yml` (`iOS Build & Test`) via GitHub CLI (`gh run list` / `gh run view <id> --log-failed`) if available, and use the `github` MCP (`list_commits`, `get_commit`, `list_pull_requests`, `pull_request_read`) to verify commit status checks and PR feedback.
3. If a remote run fails, classify the failure immediately before making edits:
   - **XcodeGen failure:** Invalid key/path/package spec in `iosApp/Project.yml`.
   - **Compiler / Concurrency error (`build-for-testing`):** Fix every Swift 6 error, missing import, or `@Sendable` diagnostic across all affected files in a single batch.
   - **Unit Test failure (`xcodebuild test`):** Compare failing XCTest assertions against `specs/01-cambridge-phases.md`, `specs/02-curriculum-skills.md`, and `specs/04-data-models.json`, fix the root cause, and add regression assertions if needed.

## Gotchas (Strict Constraints)
- **Never Relax Strict Concurrency:** Never remove `SWIFT_STRICT_CONCURRENCY: complete` or downgrade `SWIFT_VERSION` from `"6.0"` in `Project.yml` to bypass compiler warnings.
- **No Unchecked Cloud/Mock Leaks:** Verify no `#if` or `import` introduces cloud LLM SDKs or runtime network dependencies outside `ModelGateView` weight provisioning.
- **No Secrets in Commits:** Never commit PATs, `mcp_config.json`, or `.env` files into the workspace repository.
