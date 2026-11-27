# 02 — Curriculum & Skills (9-Phase Matrix)

## Topic Matrix by Phase

### Phase 1 (`A1`) — A1 Foundation (Pre-A2 Key)
| Skill ID | Topic | Example |
|----------|-------|---------|
| `A1-01` | Personal pronouns | I, you, he, she, it, we, they |
| `A1-02` | Verb "to be" | I am, you are, he is |
| `A1-03` | Articles (`a/an/the`) | a cat, an apple, the house |
| `A1-04` | Regular plurals | cats, dogs, boxes |
| `A1-05` | Simple present | I work, she studies |

### Phase 2 (`A2_INIT`) — A2 Initial (A2 Key Part 1)
| Skill ID | Topic | Example |
|----------|-------|---------|
| `A2_INIT-01` | Regular past simple | worked, played, studied |
| `A2_INIT-02` | Irregular past simple | went, saw, had |
| `A2_INIT-03` | Basic time expressions | yesterday, last week, two days ago |

### Phase 3 (`A2_INT`) — A2 Intermediate (A2 Key Part 2)
| Skill ID | Topic | Example |
|----------|-------|---------|
| `A2_INT-01` | Future with "going to" | I'm going to travel |
| `A2_INT-02` | Future with "will" | I will call you tomorrow |
| `A2_INT-03` | Comparatives and superlatives | bigger, the biggest, more interesting |

### Phase 4 (`A2_ADV`) — A2 Advanced (A2 Key Exam Ready)
| Skill ID | Topic | Example |
|----------|-------|---------|
| `A2_ADV-01` | Prepositions of place/time | in, on, at |
| `A2_ADV-02` | Quantifiers | much, many, a lot of, some, any |
| `A2_ADV-03` | Basic modals | can, could, have to |

### Phase 5 (`B1_INIT`) — B1 Initial (B1 Preliminary Part 1)
| Skill ID | Topic | Example |
|----------|-------|---------|
| `B1_INIT-01` | Present perfect (`ever/never/already/yet`) | Have you ever visited London? |
| `B1_INIT-02` | `for` vs `since` | I have lived here for 5 years / since 2021 |
| `B1_INIT-03` | Past continuous | I was reading when you called |

### Phase 6 (`B1_INT`) — B1 Intermediate (B1 Preliminary Part 2)
| Skill ID | Topic | Example |
|----------|-------|---------|
| `B1_INT-01` | Conditionals (1st & 2nd) | If I had money, I would travel |
| `B1_INT-02` | Passive voice (present & past simple) | The book was written by... |
| `B1_INT-03` | Gerunds vs infinitives | enjoy reading, decide to go |

### Phase 7 (`B1_ADV`) — B1 Advanced (B1 Preliminary Exam Ready)
| Skill ID | Topic | Example |
|----------|-------|---------|
| `B1_ADV-01` | Reported speech | She said she was tired |
| `B1_ADV-02` | Modals of deduction & advice | must, might, can't, should |
| `B1_ADV-03` | Core phrasal verbs | give up, look forward to, turn on |

### Phase 8 (`B2_INIT`) — B2 Initial (B2 First Part 1)
| Skill ID | Topic | Example |
|----------|-------|---------|
| `B2_INIT-01` | 3rd & mixed conditionals | If I had studied, I would have passed |
| `B2_INIT-02` | Defining & non-defining relative clauses | The man who lives next door |
| `B2_INIT-03` | `wish` / `if only` | I wish I had known earlier |

### Phase 9 (`B2_ADV`) — B2 Advanced (B2 First Exam Ready)
| Skill ID | Topic | Example |
|----------|-------|---------|
| `B2_ADV-01` | Key word transformations | Cambridge Use of English Part 4 rewrites |
| `B2_ADV-02` | Advanced collocations | make a decision, do homework, take responsibility |
| `B2_ADV-03` | Discourse markers & linking words | however, nevertheless, furthermore |

## Assessment Structure & Rubrics
- **Skill Assessment Length:** 15 questions per `Attempt` (`attemptType: "skillAssessment"`, `totalQuestions: 15`), drawn from a `>15` question bank per skill (with shuffled order and randomized `distractors`, plus optional RAG-assisted contextual variation in P1+).
- **Placement Test Length:** 18 diagnostic questions (`attemptType: "placementTest"`, `skillId: nil`, `totalQuestions: 18`), using 2 `isPlacementEligible == true` questions per phase from `A1` to `B2_ADV`, evaluated sequentially (`>= 1.5 / 2.0` per phase to advance; first phase `< 1.5` sets target $K$, capped at Phase 9 `B2_ADV`).
- **Question Types (`04-data-models.json`):**
  - `multipleChoice` & `reorder`: Binary grading (`+1.0` or `0.0`).
  - `fillBlank` & `translation`: Supports full (`+1.0`), partial (`+0.5`), and incorrect (`0.0`) grading against `correctAnswer` and `acceptedSynonyms`.
- **Deterministic Offline Partial-Credit Rule:**
  - All test grading runs deterministically in pure Swift `Domain` logic with **zero AI inference**.
  - Normalize user input and target strings before comparison (trim leading/trailing whitespace, collapse repeated spaces, normalize case/typographic apostrophes; for `fillBlank` and `translation`, also strip trailing terminal punctuation `.`, `?`, `!`). Contractions (`I'm` vs `I am`) are controlled per question via explicit `acceptedSynonyms` rather than global expansion.
  - On `fillBlank` and `translation`, if the normalized response does not match `correctAnswer` or any entry in `acceptedSynonyms` exactly, evaluate normalized **Levenshtein edit distance** against `correctAnswer` and each `acceptedSynonyms` candidate: award `+0.5` partial credit when edit distance is `<= 2` (or `<= 1` when the target answer/word has fewer than 5 characters); otherwise award `0.0`. Empty normalized inputs always score `0.0`.
- **Rubric Points & `AnswerRecord` Mapping:**
  - **Correct (`pointsEarned = 1.0`):** Exact normalized match to `correctAnswer` or `acceptedSynonyms` (`isCorrect = true`; increments `Attempt.correctAnswers` and adds `1.0` to `Attempt.earnedPoints`).
  - **Partial (`pointsEarned = 0.5`):** Passes deterministic Levenshtein threshold on `fillBlank`/`translation` (`isCorrect = false`; does not increment `Attempt.correctAnswers`, adds `0.5` to `Attempt.earnedPoints` / `Attempt.score`).
  - **Incorrect (`pointsEarned = 0.0`):** Concept, structural, vocabulary, or Spanish-interference error (`isCorrect = false`) → triggers immediate Spanish feedback sheet in `TestView` (stored in `AnswerRecord.ragFeedback`) and queues the question for `"Practice Missed Questions"` (`MistakeDrillView`).
