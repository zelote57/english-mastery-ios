# 01 — Cambridge CEFR 9-Phase Reference Matrix

## Product & Exam Alignment
- **Goal:** Prepare Spanish-speaking learners for official Cambridge English Qualifications (**A2 Key**, **B1 Preliminary**, **B2 First**) from A1 foundation to B2 Advanced mastery.
- **Hardware & Offline Baseline:** iPhone 13 (A15 Bionic) and newer, iOS 17.0+, 100% offline execution for tests, grading, and local RAG retrieval (only initial local LLM model provisioning in `ModelGateView` may use network).

## 9-Stage Sequential Curriculum

| Order | Phase Code | Level Title | Cambridge Alignment | Core Grammatical & Lexical Focus |
|-------|------------|-------------|---------------------|----------------------------------|
| 1 | `A1` | A1 Foundation | Pre-A2 Key | Personal pronouns, verb "to be", articles, regular plurals, simple present |
| 2 | `A2_INIT` | A2 Initial | A2 Key (Part 1) | Regular & irregular past simple, basic time expressions (`yesterday`, `ago`) |
| 3 | `A2_INT` | A2 Intermediate | A2 Key (Part 2) | Future forms (`going to`, `will`), comparatives & superlatives |
| 4 | `A2_ADV` | A2 Advanced | A2 Key (Exam Ready) | Prepositions of place/time (`in/on/at`), quantifiers (`much/many`), basic modals |
| 5 | `B1_INIT` | B1 Initial | B1 Preliminary (Part 1) | Present perfect (`ever/never/already/yet`), `for` vs `since`, past continuous |
| 6 | `B1_INT` | B1 Intermediate | B1 Preliminary (Part 2) | 1st & 2nd conditionals, passive voice (present & past simple), gerunds vs infinitives |
| 7 | `B1_ADV` | B1 Advanced | B1 Preliminary (Exam Ready) | Reported speech, modals of deduction (`must/might/can't`), core phrasal verbs |
| 8 | `B2_INIT` | B2 Initial | B2 First (Part 1) | 3rd & mixed conditionals, defining/non-defining relative clauses, wish/if only |
| 9 | `B2_ADV` | B2 Advanced | B2 First (Exam Ready) | Key word transformations, advanced collocations (`make/do/take`), discourse markers |

> **Note:** Exact `Phase.level` enum contracts are maintained in `04-data-models.json`, and the complete per-phase skill matrix is defined in `02-curriculum-skills.md`.

## Assessment Constants
- **Placement Test:** 18 questions total (2 diagnostic questions per phase from `A1` to `B2_ADV`).
- **Skill Test Length:** 15 questions per assessment session.
- **Passing Score:** `>= 0.80` (at least 12 correct answers out of 15).
- **Retake Policy:** Unlimited attempts; post-test mistake drill (`Practice Missed Questions`) available exclusively for missed questions.

## Onboarding & Placement Routing
On first launch, local seeding automatically creates the default local `User` profile (`name: "Learner"`, `hasCompletedOnboarding: false`) alongside all 9 `Phase` and 29 `Skill` records.

After `ModelGateView` loads the local curriculum (currently a placeholder for future model provisioning), new users choose between:
1. **Start from Scratch:** Sets `user.currentPhaseId` to Phase 1 (`A1`) with status `available`; Phases 2–9 start `locked`.
2. **Take Placement Test:** Runs the 18-question diagnostic test (2 questions per phase, ordered/evaluated sequentially across `A1`…`B2_ADV`).
   - **Placement Rule (Sequential Block Threshold):** Evaluate each phase block $1 \dots 9$ in ascending order. A phase is cleared during placement only when both diagnostic questions are correct (`2.0 / 2.0`).
   - **Target Phase $K$:** $K$ is the **first** phase where the user scores less than `2.0` points (stopping at the first failed tier so later guesses do not skip foundational gaps). If the user clears all 9 phases (`1...9`), place them at $K = 9$ (`B2_ADV`) as `available` so exam-ready mastery can be completed.
   - **Routing Outcome at Phase $K$:**
     - Phases $1 \dots K-1$ are marked `SKIPPED_PASSED` (`skippedPassed` — unlocked for optional practice without blocking progression).
     - Phase $K$ is marked `available` and assigned to `user.currentPhaseId`.
     - Phases $K+1 \dots 9$ remain `locked`.

## Phase Progression & UI States
- Each phase contains **N skills** (defined in `02-curriculum-skills.md`).
- To advance to the next phase, the user must pass **all skills** in the current phase (`isPassed == true`).
- A skill is passed when its monotonic `bestScore >= 0.80`.
- Within the UI (`05-ui-flows.md`), skills and phases reflect four states:
  - `passed` (`✅`): `skill.isPassed == true` (`bestScore >= 0.80`)
  - `skippedPassed` (`⏭️`): Unlocked via Placement Test in phases $1 \dots K-1$ for optional practice
  - `available` (`🔵`): Unlocked in the current or completed phase
  - `locked` (`🔒`): Belongs to a phase ahead of `user.currentPhaseId`

## Assessment Scoring Rules
Each question in a test is graded according to the rubrics in `02-curriculum-skills.md`:
- **Correct (`+1.0` point):** Exact answer or accepted synonym (`isCorrect = true`).
- **Incorrect (`0.0` points):** Any answer that does not match an accepted answer after normalization, including spelling mistakes (`isCorrect = false`) → triggers an immediate Spanish feedback sheet in `TestView` and queues the question for the post-test drill. Today the explanation is deterministic; RAG + LLM feedback is planned for Milestone 4.

Existing attempts and progress, including historical partial-credit results, remain unchanged.

The normalized attempt score is `earnedPoints / Double(totalQuestions)` (ranging from `0.0` to `1.0`).

## Infinite Repetition & Drill Score Isolation
- Official 15-question skill assessments can be retaken **without limit**, shuffling question order and distractor positions on every attempt.
- Every completed official assessment creates an `Attempt` record with `timestamp`, `score`, `earnedPoints`, `totalQuestions`, `correctAnswers`, and linked `[AnswerRecord]` items.
- `bestScore` is updated monotonically (`max(bestScore, attempt.score)`). Once a skill is passed (`isPassed == true`), a lower score on a later practice attempt **never** revokes `isPassed`.
- `SkillDetailView` displays the user's **best attempt** (`bestScore`), total attempts, and the **improvement trend** across the last 5 official attempts.
- **Streak Rule:** `user.streakDays` increments by 1 when a completed `skillAssessment` occurs on the next calendar day relative to `user.lastPracticeDate` (stays unchanged on the same day, resets to `1` after missed days, regardless of whether the attempt passed or failed). Neither `placementTest` nor mistake drills affect `streakDays`.
- **Drill Score Isolation:** Completing `"Practice Missed Questions"` updates learning reinforcement only; it **never** creates an official `Attempt`, **never** overwrites `Attempt.score` or `Skill.bestScore`, and **never** unlocks a skill or phase.

## Approval Logic
```swift
// Evaluate skill mastery after recording an official Attempt
if attempt.score > skill.bestScore {
    skill.bestScore = attempt.score
}

if skill.bestScore >= 0.80 {
    skill.isPassed = true
}

// Advance only when evaluating the user's active currentPhase (optional practice in
// skippedPassed or already-completed phases must never alter user.currentPhaseId)
if skill.phaseId == user.currentPhaseId,
   activePhase.skills.allSatisfy(\.isPassed) {
    activePhase.status = .completed

    if let nextPhase = orderedPhases.next(after: activePhase) {
        nextPhase.status = .available
        user.currentPhaseId = nextPhase.id
    }
}
```

## AI Tutor Feedback
- On each incorrect (`0.0`) answer during a skill assessment in `TestView`, progression pauses and a deterministic Spanish explanation with three headings is stored in `AnswerRecord.ragFeedback` for later review. The on-device RAG + LLM pipeline described in `03-rag-architecture.md` is the Milestone 4 target, not the current behavior.
- All SwiftUI controls, titles, buttons (e.g., `"Continue"`), and test prompts remain strictly in **English**, while pedagogical error explanations are generated in **Spanish**.
