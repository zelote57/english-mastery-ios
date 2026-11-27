// Chunk.swift
// SwiftData model for a text chunk used by the RAG pipeline.

import Foundation
import SwiftData

@Model
public final class Chunk {
    @Attribute(.unique) public var id: UUID
    public var text: String
    // Embedding stored as JSON‑encoded [Double].
    public var embedding: Data
    // UUID of the owning Question (plain FK – avoids cross‑target circular refs).
    public var questionId: UUID?

    public init(id: UUID = UUID(), text: String, embedding: Data, questionId: UUID? = nil) {
        self.id = id
        self.text = text
        self.embedding = embedding
        self.questionId = questionId
    }
}
