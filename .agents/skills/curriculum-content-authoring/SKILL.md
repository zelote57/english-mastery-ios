---
name: curriculum-content-authoring
description: >-
  Authors and validates the 9-phase Cambridge CEFR seed dataset (9 phases, 29
  skills, >15 questions per skill, 18 placement-eligible questions) and the
  /knowledge-base/ grammar, Spanish-interference, and prompt-template Markdown
  files sized for ~300-token RAG chunking. Use during Milestone 1 data seeding
  and Milestone 3 knowledge-base creation.
---

# Curriculum & Knowledge Base Authoring Workflow

Operational manual for creating pedagogically accurate Cambridge English (`A1` to `B2_ADV`) test banks for Milestone 1 seeding and RAG-ready Markdown knowledge assets for Milestone 3.

## Reference Specs & Asset Maps (Progressive Disclosure)

Consult these files before authoring seed questions or knowledge-base documents:
- [01-cambridge-phases.md](../../../specs/01-cambridge-phases.md) — 9-phase tier definitions (`A1` to `B2_ADV`) and Cambridge exam alignment (`A2 Key`, `B1 Preliminary`, `B2 First`).
- [02-curriculum-skills.md](../../../specs/02-curriculum-skills.md) — Canonical 29 `skillCode` entries, topics, `questionType` rules, and binary grading rubric.
- [04-data-models.json](../../../specs/04-data-models.json) — Exact schemas for `Phase`, `Skill`, `Question`, and `Chunk`.
- [grammar-rules/README.md](../../../knowledge-base/grammar-rules/README.md) — Exact file tree mapping the 26 grammar `.md` files to all 29 skills.
- [spanish-interference/README.md](../../../knowledge-base/spanish-interference/README.md) — Error categories (`False Friends`, `Problematic Prepositions`, `Structural Errors`) and document contract.
- [prompt-templates/README.md](../../../knowledge-base/prompt-templates/README.md) — Base template placeholders, 3-heading Spanish contract, `< 150` word limit, and 4 required variant files.

## Step-by-Step Authoring Procedure

### 1. Milestone 1 — Curated Question Bank (`>15` Questions × 29 Skills)
When building the deterministic seed dataset under `iosApp/Sources/Data/`:
1. **Complete Phase & Skill Matrix:** Seed all 9 `Phase` entries (`order: 1...9`) and all 29 `Skill` entries matching every exact `skillCode` in `02-curriculum-skills.md`.
2. **Anti-Memorization Bank Depth:** Author **at least 16–20 questions per skill** (`>15` required per skill = `>435` minimum across the 29 skills) so the 15-question assessment sampler can rotate unseen/missed questions across retakes.
3. **Placement Calibration (`18` Questions):** Mark **exactly 2 questions per phase** (`isPlacementEligible = true`, `9 × 2 = 18` total) that directly test the core grammar diagnostic of that tier without obscure edge cases.
4. **Question Type Authoring Rules:**
   - `multipleChoice`: Include 3 plausible `distractors`. Design at least 1–2 distractors per question around realistic Spanish-to-English interference errors (e.g., `"I have 20 years"`, `"depends of"`, `"actually"` used as `"currently"`). Never include `correctAnswer` inside `distractors`.
   - `fillBlank` & `translation`: Populate `acceptedSynonyms` with legitimate grammatical equivalents (e.g., `["I am going to", "I'm going to"]`, `["do not", "don't"]`) so valid forms score `+1.0`; spelling mistakes score `0.0`.
   - `reorder`: Provide unambiguous scrambled tokens in `prompt` and the single canonical English sentence in `correctAnswer`.
5. **Prompt Language Rule:** Keep all `Question.prompt` text in **English** (for `translation`, frame the instruction in English, e.g., `Translate into English: "Ella vivió en Madrid el año pasado."`).

### 2. Milestone 3 — Grammar Rules & Spanish Interference Docs (`/knowledge-base/`)
1. **Create All 26 Grammar Files:** Follow the exact directory layout and filenames in `knowledge-base/grammar-rules/README.md` (`A1/`, `A2/`, `B1/`, `B2/`).
2. **Create Categorized Interference Files:** Author dedicated `.md` files in `knowledge-base/spanish-interference/` (e.g., `false-friends.md`, `prepositions.md`, `structural-errors.md`), each with common mistake, clear explanation, rule, and 3+ contrasted examples.
3. **Chunk-Friendly Markdown Structure (~300 Tokens):**
   - Split every document into focused `##` / `###` sections of **~250–320 tokens** so the chunker preserves complete explanations and paired `❌` / `✅` examples inside a single `Chunk`.
   - Write each section as a **self-contained unit** mentioning the phase code (`A1`…`B2_ADV`), skill topic name, rule, Spanish-interference contrast (where relevant), and paired examples (`❌` wrong vs `✅` correct + Spanish translation).
   - Include natural search terms matching the runtime query pattern (`"Grammar rule for {skill.topic} and error: {userAnswer} instead of {correctAnswer}"`) so `NLEmbedding`/CoreML cosine retrieval surfaces the exact rule in the Top-3 chunks.

### 3. Prompt Template Variants (`/knowledge-base/prompt-templates/`)
Create all 4 variant files declared in `knowledge-base/prompt-templates/README.md`:
- `grammar-correction.md`
- `vocabulary-confusion.md`
- `preposition-error.md`
- `word-order.md`

Ensure every variant preserves:
- All 6 placeholders: `{level}`, `{skill_topic}`, `{user_answer}`, `{correct_answer}`, `{question}`, `{rag_chunks}`
- Instruction to ground exclusively in `{rag_chunks}` and stay under **150 words**
- Exact 3 Spanish Markdown headings:
  - `### 💡 ¿Por qué no es correcta?`
  - `### 📘 Regla clave`
  - `### 🔍 Ejemplos prácticos`

## Verification Checklist
Run an automated check (script or XCTest) to confirm:
- Exactly `9` phases (`A1`…`B2_ADV`) and `29` skills (`A1-01`…`B2_ADV-03`).
- Every skill has `> 15` questions and non-empty `correctAnswer`.
- Exactly `18` questions have `isPlacementEligible == true` (`2` per phase).
- No `Question` has `correctAnswer` duplicated inside `distractors` or empty `distractors` on `multipleChoice`.
- Every `.md` file listed in `grammar-rules/README.md` and `prompt-templates/README.md` exists, uses UTF-8 encoding, and keeps sections near ~300 tokens.

## Gotchas (Strict Constraints)
- **No Unbounded Prose Walls:** Long unstructured `.md` sections split awkwardly across chunk boundaries and weaken Top-3 RAG precision. Keep sections tight (~250–320 tokens) with headers and paired examples together.
- **No Ambiguous Multiple-Choice Keys:** On `multipleChoice` items, ensure none of the `distractors` could also be grammatically acceptable in standard Cambridge English.
- **Strict Language Separation:** Test prompts and answers stay in English; pedagogical explanations and Spanish-interference notes in `/knowledge-base/` prepare Spanish feedback with English example sentences.
