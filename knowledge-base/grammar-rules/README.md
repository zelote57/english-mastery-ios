# 📚 Grammar Rules — Knowledge Base

This directory contains grammar rules organized by base CEFR tier (`A1`, `A2`, `B1`, `B2`) and mapped to the 9 sequential phase codes (`A1` through `B2_ADV`) defined in `specs/02-curriculum-skills.md`.

## Expected Structure & 9-Phase Mapping
```
grammar-rules/
├── A1/                                  # Phase 1: A1
│   ├── pronouns.md                      # A1-01
│   ├── verb-to-be.md                    # A1-02
│   ├── articles.md                      # A1-03
│   ├── plurals.md                       # A1-04
│   └── present-simple.md                # A1-05
├── A2/                                  # Phases 2-4: A2_INIT, A2_INT, A2_ADV
│   ├── past-simple.md                   # A2_INIT-01, A2_INIT-02
│   ├── time-expressions.md              # A2_INIT-03
│   ├── future-forms.md                  # A2_INT-01, A2_INT-02
│   ├── comparatives.md                  # A2_INT-03
│   ├── prepositions.md                  # A2_ADV-01
│   ├── quantifiers.md                   # A2_ADV-02
│   └── basic-modals.md                  # A2_ADV-03
├── B1/                                  # Phases 5-7: B1_INIT, B1_INT, B1_ADV
│   ├── present-perfect-for-since.md     # B1_INIT-01, B1_INIT-02
│   ├── past-continuous.md               # B1_INIT-03
│   ├── conditionals-1-2.md              # B1_INT-01
│   ├── passive-voice.md                 # B1_INT-02
│   ├── gerunds-infinitives.md           # B1_INT-03
│   ├── reported-speech.md               # B1_ADV-01
│   ├── modals-deduction-advice.md       # B1_ADV-02
│   └── phrasal-verbs.md                 # B1_ADV-03
└── B2/                                  # Phases 8-9: B2_INIT, B2_ADV
    ├── conditionals-3-mixed.md          # B2_INIT-01
    ├── relative-clauses.md              # B2_INIT-02
    ├── wish-if-only.md                  # B2_INIT-03
    ├── key-word-transformations.md      # B2_ADV-01
    ├── collocations.md                  # B2_ADV-02
    └── linking-words.md                 # B2_ADV-03
```

## Format & Ingestion Contract
- Files in Markdown or PDF.
- Each file covers specific curriculum topics and includes: rule, correct examples, common incorrect examples, and Spanish-interference notes where applicable.
- During ingestion, the parser assigns each `Chunk.level` to the matching 9-phase code (`A1`…`B2_ADV`) and `Chunk.topic` for filtered VectorStore retrieval.
