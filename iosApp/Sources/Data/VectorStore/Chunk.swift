// Chunk.swift
// SwiftData model for a text chunk used by the RAG pipeline.
// Each chunk belongs to a Question and stores its embedding as binary data.

import SwiftData

@Model
public final class Chunk {
    @Attribute(.unique) public var id: UUID
    public var text: String
    // Embedding stored as Data (e.g., Float32 array encoded as JSON or binary).
    public var embedding: Data
    // Relationship to the owning Question (optional to avoid circular import).
    public var questionId: UUID

    public init(id: UUID = UUID(), text: String, embedding: Data, question: Question? = nil) {
        self.id = id
        self.text = text
        self.embedding = embedding
        self.question = question
    }
}
