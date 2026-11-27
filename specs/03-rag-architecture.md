# 03 — RAG Architecture on iOS

## Overview
Retrieval-Augmented Generation pipeline that runs **100% on-device** (iPhone 13 / A15 Bionic or newer, iOS 17.0+) to generate personalized Spanish explanations of English grammar and Cambridge Use of English errors. No cloud AI SDKs or runtime network calls are permitted during tests or RAG retrieval (network is limited exclusively to initial local model weight provisioning in `ModelGateView`).

## Pipeline Components

```
┌─────────────┐    ┌──────────────┐    ┌─────────────┐    ┌──────────┐
│  PDFKit /    │───▸│  Chunking &  │───▸│  Vector     │───▸│  LLM     │
│  Markdown   │    │  Embedding   │    │  Store      │    │  Engine  │
│  Parser     │    │  (NLEmbedding│    │  (In-memory │    │  (MLX /  │
│             │    │   / CoreML)  │    │   / SQLite) │    │  MediaPipe│
└─────────────┘    └──────────────┘    └─────────────┘    └──────────┘
```

### 1. Document Ingestion (`PDFKit Parser`)
- Reads PDF and Markdown files from `/knowledge-base/` (`grammar-rules/`, `spanish-interference/`, `prompt-templates/`).
- Extracts plain text and splits it into chunks of ~300 tokens preserving sentence/example boundaries.
- Each chunk stores metadata: `level` (mapped to the 9 phase codes `A1`…`B2_ADV`), `topic`, `sourceFile`, and `chunkIndex`.
- The app bundles `/knowledge-base/` as a folder. `manifest.json` lists each indexed Markdown/PDF file and its phase and topic; currently only the entries in the manifest are indexed.
- Chunking uses approximately 225 word tokens as a 300-token estimate. Paragraphs and sentences are kept together where possible; exceptionally long sentences are split at word boundaries.

### 2. Embedding (`NLEmbedding` / CoreML)
- **Option A:** `NLEmbedding` from Apple's `NaturalLanguage` framework (fast, built-in, offline).
- **Option B:** Custom CoreML embedding model for higher semantic precision.
- Generates 128–512 dimensional `[Float]` vectors per chunk.
- The initial implementation averages the available English `NLEmbedding` word vectors for the document or query. Missing models or texts with no recognized words produce errors; the embedding instance is actor-isolated.

### 3. Vector Store
- Storage in SQLite with vector search extension or an in-memory cosine similarity index.
- HNSW index for efficient search when exceeding 1,000 chunks.
- Supports metadata filtering/prioritization by `level` and `topic` (including `spanish-interference` chunks).
- The current index is in memory and uses exact cosine ranking with optional phase and topic filters. HNSW and index persistence are not yet implemented.

### 4. On-Device LLM Generation
- **MLX Swift:** Quantized small models (`Gemma` / `Phi-3-mini`) running locally on Apple Silicon via an `actor`-isolated engine.
- **MediaPipe LLM Inference:** Cross-platform alternative by Google.
- Prompt instructs the model to rely **strictly** on retrieved chunks (`grounded context only`) and respond in **Spanish** using the 3-section Duolingo-style template (max 150 words).
- **Non-blocking Execution:** Streams tokens or shows a thinking indicator on the `TestView` feedback sheet while inference executes asynchronously; never blocks the main UI thread.

## Query Flow (Immediate Interruption on Wrong Answer)
1. User submits an incorrect (`0.0` pt) answer in `TestView` → test progression pauses immediately.
2. Query is built: `"Grammar rule for {skill.topic} and error: {userAnswer} instead of {correctAnswer}"`.
3. **Top-3 most relevant chunks** are retrieved from the `VectorStore` via cosine similarity.
4. Prompt is assembled with the error template variant, `{level}`, `{user_answer}`, `{correct_answer}`, `{question}`, and `{rag_chunks}`.
5. On-device LLM generates the **Spanish** explanation (`### 💡 ¿Por qué no es correcta?`, `### 📘 Regla clave`, `### 🔍 Ejemplos prácticos`) — or deterministic fallback card in Milestone 0–2 / if LLM fails.
6. Sheet displays the explanation until the user taps **"Continue"**, and saves it in `AnswerRecord.ragFeedback` for review in `FeedbackView`.
