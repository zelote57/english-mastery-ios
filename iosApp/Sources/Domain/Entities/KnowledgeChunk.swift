import Foundation

struct KnowledgeChunk: Identifiable, Equatable, Sendable {
    let id: UUID
    let sourceFile: String
    let content: String
    let level: PhaseLevel
    let topic: String
    let chunkIndex: Int

    init(id: UUID = UUID(), sourceFile: String, content: String, level: PhaseLevel, topic: String, chunkIndex: Int) {
        self.id = id
        self.sourceFile = sourceFile
        self.content = content
        self.level = level
        self.topic = topic
        self.chunkIndex = chunkIndex
    }
}
