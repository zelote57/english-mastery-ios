// DataLayer.swift
// SwiftData, PDFKit Parser, VectorStore, LLM Engine
//
// Concrete implementations of the interfaces defined in Domain.
// - Persistence/: SwiftData @Model entities and repositories
// - PDFParser/: Text extraction from PDF/Markdown with PDFKit
// - VectorStore/: Embedding storage and search
// - LLMEngine/: Integration with MLX Swift or MediaPipe

// TODO: Implement data layer according to specs/03-rag-architecture.md

/// Namespace for the Data layer.
import SwiftData

import SwiftData

enum DataLayer {
    // Simple embedding provider using Gemini on‑device API.
    static var embedder = GeminiEmbeddingProvider()
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
    // Simple embedding provider using Gemini on‑device API.
    static var embedder = GeminiEmbeddingProvider()
    // SwiftData container holding the persistence models used for RAG.
    static let container: ModelContainer = {
        // Currently we only have Chunk as a @Model; add others when they become models.
        let schema = Schema([Chunk.self])
        return try! ModelContainer(for: schema, configurations: [])
    }()
}
    // Simple embedding provider using Gemini on‑device API.
    static let embedder = GeminiEmbeddingProvider()
    // SwiftData container holding the persistence models used for RAG.
    static let container: ModelContainer = {
        // Currently we only have Chunk as a @Model; add others when they become models.
        let schema = Schema([Chunk.self])
        return try! ModelContainer(for: schema, configurations: [])
    }()
}
    // Simple embedding provider using Gemini on‑device API.
    // The provider returns the embedding as JSON‑encoded Data (Float64 array).
    static let embedder = GeminiEmbeddingProvider()
}
