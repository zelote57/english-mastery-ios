---
name: duolingo-rag-tutor
description: >-
  Builds and verifies the 100% on-device RAG retrieval pipeline (PDFKit/Markdown
  ingestion, ~300-token chunking, NLEmbedding/CoreML, VectorStore cosine
  search, MLX Swift/MediaPipe LLM inference) to generate Duolingo-style
  pedagogical error explanations in Spanish for Spanish-speaking learners. Use
  when implementing TestView immediate error sheets, RAG context retrieval,
  prompt templates, FeedbackView explanations, or RAG unit tests.
---

# Duolingo-Style Local RAG Tutor Workflow

Operational manual for the 100% on-device Retrieval-Augmented Generation (RAG)
pipeline and Spanish pedagogical error-explanation sheets in `iosApp/`.

## Reference Specs (Progressive Disclosure)

Consult these specs and knowledge-base docs before building or modifying RAG code:
- [03-rag-architecture.md](../../../specs/03-rag-architecture.md) — On-device `PDFKit`, `NLEmbedding`, `VectorStore`, `MLX Swift`/`MediaPipe` architecture and query flow.
- [04-data-models.json](../../../specs/04-data-models.json) — Schemas for `Chunk` (9-phase `level` enum) and `AnswerRecord.ragFeedback`.
- [05-ui-flows.md](../../../specs/05-ui-flows.md) — `ModelGateView` provisioning, `TestView` immediate error sheet, and `FeedbackView` error cards.
- [prompt-templates/README.md](../../../knowledge-base/prompt-templates/README.md) — Base Spanish-output template, error variants, and tone rules.
- [spanish-interference/README.md](../../../knowledge-base/spanish-interference/README.md) — False friends, prepositions, and structural interference patterns.
- [grammar-rules/README.md](../../../knowledge-base/grammar-rules/README.md) — Grammar documents mapped to the 9 phases (`A1` to `B2_ADV`).
- [AGENTS.md](../../../AGENTS.md) — Swift 6 strict concurrency (`Sendable`, `actor`), SwiftUI, and MVVM conventions.

## Pipeline Architecture (Swift 6 Strict Concurrency)

- **`iosApp/Sources/Domain/RAG/` and `Domain/Entities/`**: `EmbeddingProvider` and the `Sendable` `KnowledgeChunk` value.
- **`iosApp/Sources/Data/RAG/`**: Markdown/PDF parser, chunker, native embedding, in-memory vector store and knowledge index.
- **Current status:** Retrieval is tested independently; `TestView` uses a deterministic fallback. Model provisioning, LLM inference and RAG integration into assessments are planned for Milestone 4.
- **Physical-device validation:** The isolated diagnostic benchmark was run offline on a physical device; its results and limitations are recorded in `specs/06-roadmap-milestones.md`.

## Target Pedagogical Feedback Procedure

### 1. Knowledge Ingestion & ~300-Token Chunking
1. Scan bundled `.md` and `.pdf` assets from `/knowledge-base/` (`grammar-rules/`, `spanish-interference/`).
2. Extract plain text using `PDFKit` (`PDFDocument` / `PDFPage.string`) for PDFs and UTF-8 string parsing for Markdown.
3. Split extracted text into chunks of **~300 tokens**, preserving sentence and example boundaries.
4. Populate every `Chunk` with `sourceFile`, `content`, `level` (mapped to `A1`…`B2_ADV`), `topic`, and `chunkIndex`, then index 128–512d `[Float]` embeddings.

### 2. Immediate Interruption on Wrong Answer & Top-3 Retrieval
1. When the user submits an incorrect (`0.0` pt) answer during a skill assessment in `TestView`, pause test progression immediately (diagnostic `PlacementTestView` suppresses mid-test RAG sheets).
2. Trigger an asynchronous local query to the `VectorStore` using:
   `"Grammar rule for {skill.topic} and error: {userAnswer} instead of {correctAnswer}"`
3. Retrieve the **Top-3 most relevant chunks** via cosine similarity. Current level/topic filters exclude interference documents with different metadata; design and verify inclusion of applicable interference context during integration.

### 3. On-Device LLM Prompt Assembly & Non-Blocking Execution
1. Confirm `ModelGateView` readiness (`ready`) before invoking local inference.
2. Select the matching error template variant from `/knowledge-base/prompt-templates/`:
   - `grammar-correction.md` — Grammatical structure errors
   - `vocabulary-confusion.md` — False friends and lexical confusion
   - `preposition-error.md` — Incorrect prepositions
   - `word-order.md` — Incorrect word order
3. Populate `{level}`, `{skill_topic}`, `{user_answer}`, `{correct_answer}`, `{question}`, and `{rag_chunks}`.
4. Inject the retrieved chunks into the `actor`-isolated local LLM (`Gemma` / `Phi-3-mini` via MLX Swift or MediaPipe) with strict instructions to rely **only** on `{rag_chunks}` and respond in **Spanish** using the exact template below.
5. Stream tokens or display a local thinking indicator on the `TestView` feedback sheet while inference runs asynchronously — never block the `@MainActor` UI thread.

### 4. Required Output Template (Copy Exactly)
The response rendered in the `TestView` feedback sheet and saved to `AnswerRecord.ragFeedback` MUST follow this structure (max **150 words**):

```markdown
### 💡 ¿Por qué no es correcta?
[1-2 sentences in clear Spanish explaining the exact mistake, explicitly mentioning Spanish-to-English interference if applicable.]

### 📘 Regla clave
[1-2 sentences summarizing the English grammar or Cambridge Use of English rule in simple terms.]

### 🔍 Ejemplos prácticos
- ❌ *"[Incorrect sentence mirroring the user's mistake]"*
- ✅ *"[Corrected English sentence]"* — ([Natural Spanish translation])
```

### 5. Active Acknowledgment, Persistence & Graceful Fallback
1. **Active Acknowledgment:** Require the user to tap the English **"Continue"** button on the `TestView` feedback sheet before advancing to the next question.
2. **Persistence:** Save the generated explanation in `AnswerRecord.ragFeedback` so it can be reviewed later as expandable cards in `FeedbackView`.
3. **Graceful Fallback:** Before LLM integration or if the local LLM fails/times out, return a deterministic Spanish fallback card adhering to the exact 3-heading Markdown template above using the Top-1 retrieved chunk (or skill rule summary), so `TestView` and `FeedbackView` never render empty errors. The current fallback uses a skill rule, not retrieved context.

### 6. Unit Testing & Verification (`iosApp/Tests/`)
- Verify chunking stays near ~300 tokens and preserves `level` (`A1`…`B2_ADV`), `topic`, and `chunkIndex` metadata.
- Verify cosine similarity calculation and Top-3 retrieval ranking with mock embeddings.
- Verify prompt builder injects all placeholders, enforces `< 150` words, and requires Spanish output with the 3 exact Markdown headings.
- Verify graceful fallback returns valid 3-heading Spanish Markdown when the LLM mock throws or is unavailable.

## Gotchas (Strict Constraints)
- **Language Lock:** Even though all SwiftUI UI controls (including the `"Continue"` button) and prompt instructions are in **English**, the generated pedagogical explanation **MUST be written in Spanish** (with English example sentences and natural Spanish translations) so the learner grasps nuances immediately.
- **No Unhandled Latency Blocking:** Stream tokens or show a subtle local thinking indicator on the feedback sheet while MLX Swift runs on-device inference on iPhone 13 (A15 Bionic) or newer; never freeze the main UI thread.
- **Grounded Context Only:** Instruct the local LLM to rely strictly on the retrieved `/knowledge-base/` chunks and avoid inventing complex linguistic jargon.
- **100% Offline Retrieval & Inference:** Never import cloud AI SDKs or make network calls during query retrieval or LLM explanation generation.
