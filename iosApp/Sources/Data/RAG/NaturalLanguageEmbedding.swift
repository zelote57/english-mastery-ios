import Foundation
import NaturalLanguage

actor NaturalLanguageEmbedding: EmbeddingProvider {
    enum EmbeddingError: Error, Equatable {
        case unavailable
        case noRecognizedWords
    }

    private let embedding: NLEmbedding?

    init() {
        embedding = NLEmbedding.wordEmbedding(for: .english)
    }

    func embed(_ text: String) throws -> [Float] {
        guard let embedding else { throw EmbeddingError.unavailable }
        let normalized = text.lowercased()
        let tokenizer = NLTokenizer(unit: .word)
        tokenizer.string = normalized
        var sum = Array(repeating: 0.0, count: embedding.dimension)
        var count = 0
        tokenizer.enumerateTokens(in: normalized.startIndex..<normalized.endIndex) { range, _ in
            guard let vector = embedding.vector(for: String(normalized[range])),
                  vector.count == sum.count else { return true }
            for index in sum.indices { sum[index] += vector[index] }
            count += 1
            return true
        }
        guard count > 0 else { throw EmbeddingError.noRecognizedWords }
        return sum.map { Float($0 / Double(count)) }
    }
}
