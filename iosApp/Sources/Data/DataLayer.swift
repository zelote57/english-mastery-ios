// DataLayer.swift
// SwiftData, PDFKit Parser, VectorStore, LLM Engine
//
// Concrete implementations of the interfaces defined in Domain.
// - Persistence/: SwiftData @Model entities and repositories
// - PDFParser/: Text extraction from PDF/Markdown with PDFKit
// - VectorStore/: Embedding storage and search
// - LLMEngine/: Integration with MLX Swift or MediaPipe

import SwiftData

/// Namespace for the Data layer.
enum DataLayer {
    // Simple embedding provider using Gemini on‑device API (or fallback stub).
    static let embedder = GeminiEmbeddingProvider()
    // SwiftData container holding the persistence models used for RAG.
    static let container: ModelContainer = {
        // Include all SwiftData @Model entities.
        let schema = Schema([
            Chunk.self,
            PhaseModel.self,
            SkillModel.self,
            QuestionModel.self,
            UserModel.self
        ])
        return try! ModelContainer(for: schema, configurations: [])
    }()
}
