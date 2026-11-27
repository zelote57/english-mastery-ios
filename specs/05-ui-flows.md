# 05 — UI Flows (SwiftUI)

## Current status versus target
The navigation below describes the target flow. Currently `ModelGateView` loads the local
curriculum without downloading a model, and `TestView` displays and persists a deterministic
Spanish fallback based on the skill, question, and answer. It does not retrieve RAG context,
run an LLM, or stream generated feedback. Model provisioning and dynamic explanations are
planned for Milestone 4. A separate diagnostic-only build presents the device benchmark
screen described in `06-roadmap-milestones.md`, without changing learner progress.

## Strict Language Separation Rule
- **App UI & Assessments (English):** All SwiftUI navigation titles, labels, status badges, buttons (`"Start from Scratch"`, `"Take Placement Test"`, `"Start Test"`, `"Continue"`, `"Practice Missed Questions"`, `"Retry Test"`, `"Back to Home"`, `"Next Skill"`), and test prompts MUST be in **English**.
- **Pedagogical Error Feedback (Spanish):** All RAG-generated and deterministic fallback explanations shown in the `TestView` error sheet and expanded inside `FeedbackView` MUST be in **Spanish** (with English example sentences).

## Navigation Map

```
App Launch
    │
    ▼
┌───────────────────┐
│  ModelGateView    │──── Downloading LLM weights ─────────▸ ProgressView
│                   │──── Ready & !hasCompletedOnboarding ─▸ OnboardingView
│                   │──── Ready & hasCompletedOnboarding  ─▸ HomeView
└───────────────────┘
    │
    ▼ (if !user.hasCompletedOnboarding)
┌───────────────────┐
│  OnboardingView   │──── "Start from Scratch" ───▸ Phase 1 (A1) ────▸ HomeView
│                   │──── "Take Placement Test" ──▸ PlacementTestView
└───────────────────┘                               (18 diagnostic Qs; no mid-test RAG sheets)
                                                         │
                                                         ▼ (Phase K active; 1..K-1 = skippedPassed)
┌───────────────────┐                                    │
│     HomeView      │◂───────────────────────────────────┘
│                   │──── Dashboard: active phase (1..9), streakDays, progress
│                   │──── Skills & phases (✅ passed / ⏭️ skippedPassed / 🔵 available / 🔒 locked)
└───────────────────┘
    │
    ├──▸ SkillDetailView ──▸ bestScore, attempts count, 5-attempt trend, "Start Test"
    │
    ▼
┌───────────────────┐
│     TestView      │──── 15 shuffled questions + shuffled distractors
│                   │──── On 0.0 pt error: pauses & shows Spanish RAG feedback sheet
│                   │──── Requires active tap on "Continue" to advance
└───────────────────┘
    │
    ▼ (after Question 15)
┌───────────────────┐
│     FeedbackView    │──── Official Attempt.score (celebration if >= 0.80)
│                   │──── Expandable Spanish cards from AnswerRecord.ragFeedback
│                   │──── If failedQuestions non-empty: "Practice Missed Questions"
│                   │──── "Retry Test" / "Back to Home" / "Next Skill"
└───────────────────┘
    │
    ▼ (optional isolated reinforcement)
┌───────────────────┐
│ MistakeDrillView  │──── "Practice Missed Questions" loop until answered correctly
└───────────────────┘     (Strict Drill Score Isolation: never creates Attempt or mutates score)
```

## Main Views

### 1. `ModelGateView`
- **State:** `loading` | `downloading(progress)` | `ready` | `error`
- Verifies or downloads local LLM weights into app-private storage on first use.
- Once `ready`, routes to `OnboardingView` (if `!user.hasCompletedOnboarding`) or `HomeView`.

### 2. `OnboardingView` & `PlacementTestView`
- Initial database seeding automatically provisions a default local `User` (`name: "Learner"`, `hasCompletedOnboarding: false`), allowing onboarding without a separate registration screen.
- `OnboardingView` presents two English choices:
  - **"Start from Scratch"**: Sets Phase 1 (`A1`) `status = "available"`, Phases 2–9 `status = "locked"`, assigns `user.currentPhaseId` to Phase 1, sets `user.placementPhaseCode = nil`, and marks `user.hasCompletedOnboarding = true`.
  - **"Take Placement Test"**: Launches `PlacementTestView` with **18 diagnostic questions** (`attemptType: "placementTest"`, `skillId: nil`, `totalQuestions: 18` — 2 `isPlacementEligible` questions per phase from `A1` to `B2_ADV`, run without mid-test RAG sheets). Target Phase $K$ is the first phase scoring `< 1.5 / 2.0` points sequentially from `A1` (or Phase 9 `B2_ADV` if all 9 phases clear `>= 1.5`).
- On Placement Test completion at Phase $K$:
  - Phases $1 \dots K-1$ are set to `status = "skippedPassed"` (`SKIPPED_PASSED` — unlocked for optional practice).
  - Phase $K$ is set to `status = "available"`, `user.currentPhaseId` is set to Phase $K$'s `id`, and `user.placementPhaseCode` records Phase $K$'s `level`.
  - Phases $K+1 \dots 9$ remain `status = "locked"`, and `user.hasCompletedOnboarding = true`.

### 3. `HomeView`
- Header: `user.name`, `user.streakDays`, active phase (`1`–`9`, e.g., `"Phase B1 Initial — B1 Preliminary (Part 1)"`), and overall phase progress bar.
- Phase and skill list displaying all 4 states:
  - `passed` (`✅`): `skill.isPassed == true` (`bestScore >= 0.80`)
  - `skippedPassed` (`⏭️`): Phase marked `skippedPassed` (`1...K-1`) unlocked for optional practice
  - `available` (`🔵`): Active phase (`user.currentPhaseId`) or `completed` phase skill
  - `locked` (`🔒`): Phase ahead of `user.currentPhaseId`

### 4. `SkillDetailView`
- Skill title (`skillCode` + `topic`).
- `skill.bestScore` + total official `Attempt` count (`attemptType == "skillAssessment"`).
- Improvement trend chart across the **last 5 official attempts** sorted chronologically.
- Primary button: `"Start Test"` (launches 15-question assessment).

### 5. `TestView`
- Serves 15 questions one at a time with randomized question order and randomized `Question.distractors`.
- Progress bar: `Question X of 15`.
- **Immediate Wrong-Answer Interruption:** On a `0.0` pt error (`pointsEarned == 0.0`), test progression pauses immediately and presents a feedback sheet showing a non-blocking thinking/streaming indicator while the on-device RAG + LLM pipeline (or deterministic 3-heading Spanish fallback card) generates the Spanish explanation saved to `AnswerRecord.ragFeedback`. Progression remains paused until the user taps the English **"Continue"** button.
- Partial credit (`pointsEarned == 0.5` on `fillBlank` / `translation`) shows an inline spelling hint with the target spelling and a **"Continue"** button before advancing.

### 6. `FeedbackView` & `MistakeDrillView`
- Displays official `Attempt.score` immediately after question 15 (e.g., `"80%"`), with a celebration animation if `>= 0.80`.
- Expandable list of missed questions with Spanish explanations from `AnswerRecord.ragFeedback`.
- If `failedQuestions` (`pointsEarned == 0.0`) is non-empty, displays **"Practice Missed Questions"** button launching `MistakeDrillView` (loops only missed questions until answered correctly; strictly ephemeral with zero impact on `Attempt`, `Attempt.score`, `Skill.bestScore`, `Skill.isPassed`, or `user.currentPhaseId`).
- Secondary actions: `"Retry Test"`, `"Back to Home"`, `"Next Skill"`.

## App States
```swift
enum AppState {
    case gatingModel       // Verifying/provisioning local LLM weights in ModelGateView
    case onboarding        // OnboardingView ("Start from Scratch" vs "Take Placement Test")
    case placementTest     // PlacementTestView (18 diagnostic questions, no mid-test RAG)
    case home              // HomeView (9-phase dashboard with ✅ / ⏭️ / 🔵 / 🔒)
    case skillDetail       // SkillDetailView (skill progress and assessment entry)
    case testInProgress    // TestView (15-question skill assessment + error sheet)
    case reviewingFeedback // FeedbackView (official score + expandable RAG cards)
    case mistakeDrill      // MistakeDrillView ("Practice Missed Questions" isolated loop)
}
```
