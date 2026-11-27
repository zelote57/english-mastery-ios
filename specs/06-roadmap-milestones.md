# 06 — Roadmap & Milestones

## Build Milestones

### 🏗️ Milestone 0 — Scaffolding
- [x] Create project folder structure
- [x] Configure `Project.yml` for XcodeGen
- [x] Generate clean `.xcodeproj`
- [x] Configure GitHub Actions CI/CD
- [x] Verify that the project builds empty on simulator

### 🧱 Milestone 1 — Data Models + SwiftData
- [x] Implement entities aligned with `04-data-models.json`: `User`, `Phase`, `Skill`, `Question`, `Attempt`, `AnswerRecord`
- [x] Configure `ModelContainer` and `ModelConfiguration`
- [x] Seed initial data (`Resources/seed-curriculum.json`): 9 phases (`A1` to `B2_ADV`), 29 skills, `>15` questions per skill, and 18 `isPlacementEligible` diagnostic questions (2 per phase)
- [x] Persistence, deterministic Levenshtein partial-credit, placement routing, and drill-isolation unit tests
- [x] Reconcile versioned bundled curriculum by stable IDs without resetting learner progress or historical scores

### 🎨 Milestone 2 — Main UI (without RAG)
- [x] `ModelGateView` (placeholder without real download)
- [x] `OnboardingView` (`"Start from Scratch"` vs `"Take Placement Test"`) & `PlacementTestView` (18 diagnostic questions without mid-test RAG sheets, marking `1...K-1` as `skippedPassed`)
- [x] `HomeView` with 9-phase skills list supporting all 4 states (`passed` `✅`, `skippedPassed` `⏭️`, `available` `🔵`, `locked` `🔒`)
- [x] `SkillDetailView` with 5-attempt history
- [x] `TestView` with 15-question shuffled flow and immediate wrong-answer sheet (`"Continue"` button) rendering the deterministic 3-heading Spanish fallback card (`### 💡 ¿Por qué no es correcta?`, `### 📘 Regla clave`, `### 🔍 Ejemplos prácticos`)
- [x] `FeedbackView` with official score summary, expandable 3-heading Spanish fallback cards, and `MistakeDrillView` (`"Practice Missed Questions"` isolated loop)

### 🔍 Milestone 3 — RAG Pipeline
- [x] Markdown/PDF parser with PDFKit
- [x] Document chunking (~225 words as an approximate 300-token target) with 9-phase `level` metadata (`A1` to `B2_ADV`)
- [x] Embeddings with `NLEmbedding`
- [x] In-memory VectorStore with cosine similarity search
- [x] Pipeline unit tests
- [x] Add grammar, Spanish-interference, and prompt-template knowledge assets for all 29 skills and 9 phases
- [x] Evaluate retrieval relevance against representative seeded mistakes across all 29 skills
- [x] Produce a device-compatible unsigned diagnostic IPA in GitHub Actions for personal installation with Sideloadly
- [x] Add a diagnostic-only screen to run the benchmark on a device and export the results
- [x] Install the IPA, execute the diagnostic offline on a physical iPhone, and review the resulting evidence

The simulator retrieval benchmark uses 36 zero-point answers from 29 skills. The explicitly
selected rule appeared in the filtered top three for 36/36 queries and ranked first for 33/36.
This representative sample does not establish relevance for every question or unfiltered
search. The diagnostic and standard builds and 44 tests passed in
[GitHub Actions run 46074217849](https://github.com/zelote57/english-mastery-ios/actions/runs/46074217849)
for commit `c119781`. The exported physical-device report for that commit recorded 36/36
top-3, 33/36 top-1, no errors, and usable timing and sampled memory measurements. The owner
confirmed a fresh launch with the device offline. This validates the diagnostic path, not every
possible app path or a performance target.

The report's app version is `unavailable`: `Project.yml` does not explicitly configure a
marketing version, and the precise cause of the missing runtime value has not been verified.
The commit SHA identifies this build; configure and verify a release version before distribution.

#### Physical-device validation procedure
1. After simulator tests pass, Actions builds for a generic iOS **device**, packages the unsigned
   `.app` under `Payload/` in an IPA, and publishes it as a downloadable artifact with its commit
   SHA and build identity. Verify the artifact and Sideloadly compatibility on a real device
   rather than assuming an unsigned package is installable.
2. The owner downloads the IPA and signs and installs it locally with Sideloadly and their own
   Apple account. Keep credentials, private keys, provisioning profiles, and device identifiers
   out of the repository, GitHub artifacts, and the diagnostic report. Sideloading can be subject
   to device, account, signing, and OS restrictions; installation is a separate acceptance check.
3. Use the English-language diagnostic screen available **only in the diagnostic build**. It uses
   the real bundled corpus, native embedding, index, and the same 36 seeded cases and relevance
   judgments shared with the simulator benchmark. It does not modify learner progress or
   invoke the LLM; missing embeddings and indexing or retrieval failures are reported.
4. After installation, enable airplane mode and verify Wi-Fi and cellular connectivity are off.
   Run the diagnostic from a fresh app launch and record indexing time, per-query retrieval
   timings and their average, sampled resident memory and its method, top-1/top-3 results, and errors.
   Record unavailable measurements explicitly. Airplane mode is a manual test condition, not
   proof that every possible execution path is network-free.
5. Export a shareable local JSON report containing the app build and commit SHA, benchmark and
   curriculum version and manifest hash, device model identifier and iOS version, manual offline-condition confirmation,
   result counts, per-case IDs and ranks, timing units and memory measurement, and failures.
   Exclude user answers, learner data, account information, UDID, and credentials. The owner
   reviews and shares it after the offline run; the app must not upload it automatically.
6. Close Milestone 3 only after successful installation, completion of all 36 cases with the
   expected rule in top-3 for each, no hidden errors, and a reviewed report with usable timing
   and memory evidence. Investigate discrepancies or unavailable measurements rather than
   marking the milestone complete. No latency or memory pass threshold is currently specified;
   define one before claiming that a particular performance target has been met. Instruments
   profiling and release distribution remain Milestone 5 work.

### 🤖 Milestone 4 — LLM Integration
- [ ] Integrate MLX Swift (or MediaPipe) for on-device inference (`Gemma` / `Phi-3-mini`)
- [ ] Real `ModelGateView` with app-private model download
- [ ] Streaming Spanish RAG-augmented explanation sheet in `TestView`
- [ ] Persist dynamic `ragFeedback` to `AnswerRecord` for `FeedbackView`
- [ ] Integrate retrieval into the assessment flow and verify appropriate Spanish-interference context for each relevant error

### 🎯 Milestone 5 — Polish & Release
- [ ] Animations and micro-interactions
- [ ] Full dark mode
- [ ] Accessibility (VoiceOver, Dynamic Type)
- [ ] Performance profiling on iPhone 13+ (Instruments)
- [ ] TestFlight beta
- [ ] App Store submission

## Priorities
> **P0:** Milestones 0-2 (functional app without AI)
> **P1:** Milestones 3-4 (RAG + on-device LLM)
> **P2:** Milestone 5 (polish and launch)

Curriculum version 4 corrects individual answer data. Existing installations reconcile bundled
content transactionally on launch; attempts and their original scores remain unchanged.
Historical answers reference question IDs rather than question-text snapshots, so later
content edits can change the wording displayed with an older attempt.
