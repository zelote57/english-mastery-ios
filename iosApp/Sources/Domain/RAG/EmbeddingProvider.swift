import Foundation

protocol EmbeddingProvider: Sendable {
    func embed(_ text: String) async throws -> [Float]
}
