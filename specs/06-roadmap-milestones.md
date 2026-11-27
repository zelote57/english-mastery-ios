# 06 — Roadmap & Milestones

## Build Milestones

### 🏗️ Milestone 0 — Scaffolding
- [x] Create project folder structure
- [x] Configure `Project.yml` for XcodeGen
- [x] Generate clean `.xcodeproj`
- [x] Configure GitHub Actions CI/CD
- [x] Verify that the project builds empty on simulator

### 🧱 Milestone 1 — Data Models + SwiftData
- [ ] Implement entities aligned with `04-data-models.json`: `User`, `Phase`, `Skill`, `Question`, `Attempt`, `AnswerRecord`
- [ ] Configure `ModelContainer` and `ModelConfiguration`
- [ ] Seed initial data (`Resources/seed-curriculum.json`): 9 phases (`A1` to `B2_ADV`), 29 skills, `>15` questions per skill, and 18 `isPlacementEligible` diagnostic questions (2 per phase)
- [ ] Persistence, deterministic Levenshtein partial-credit, placement routing, and drill-isolation unit tests

### 🎨 Milestone 2 — Main UI (without RAG)
- [ ] `ModelGateView` (placeholder without real download)
- [ ] `OnboardingView` (`"Start from Scratch"` vs `"Take Placement Test"`) & `PlacementTestView` (18 diagnostic questions without mid-test RAG sheets, marking `1...K-1` as `skippedPassed`)
- [ ] `HomeView` with 9-phase skills list supporting all 4 states (`passed` `✅`, `skippedPassed` `⏭️`, `available` `🔵`, `locked` `🔒`)
- [ ] `SkillDetailView` with 5-attempt history
- [ ] `TestView` with 15-question shuffled flow and immediate wrong-answer sheet (`"Continue"` button) rendering the deterministic 3-heading Spanish fallback card (`### 💡 ¿Por qué no es correcta?`, `### 📘 Regla clave`, `### 🔍 Ejemplos prácticos`)
- [ ] `FeedbackView` with official score summary, expandable 3-heading Spanish fallback cards, and `MistakeDrillView` (`"Practice Missed Questions"` isolated loop)

### 🔍 Milestone 3 — RAG Pipeline
- [ ] Markdown/PDF parser with PDFKit
- [ ] Document chunking (~300 tokens) with 9-phase `level` metadata (`A1` to `B2_ADV`)
- [ ] Embeddings with `NLEmbedding`
- [ ] VectorStore with cosine similarity search
- [ ] Pipeline unit tests

### 🤖 Milestone 4 — LLM Integration
- [ ] Integrate MLX Swift (or MediaPipe) for on-device inference (`Gemma` / `Phi-3-mini`)
- [ ] Real `ModelGateView` with app-private model download
- [ ] Streaming Spanish RAG-augmented explanation sheet in `TestView`
- [ ] Persist dynamic `ragFeedback` to `AnswerRecord` for `FeedbackView`

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
