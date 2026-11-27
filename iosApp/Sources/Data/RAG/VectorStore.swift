import Foundation

struct IndexedChunk: Sendable {
    let chunk: KnowledgeChunk
    let vector: [Float]
}

actor VectorStore {
    enum StoreError: Error, Equatable {
        case invalidVector
        case dimensionMismatch
        case emptyIndex
    }

    private var entries: [IndexedChunk] = []
    private var dimension: Int?

    func replace(with entries: [IndexedChunk]) throws {
        guard !entries.isEmpty else { throw StoreError.emptyIndex }
        var expected: Int?
        for entry in entries {
            try Self.validate(entry.vector)
            if let expected, entry.vector.count != expected { throw StoreError.dimensionMismatch }
            expected = entry.vector.count
        }
        self.entries = entries
        dimension = expected
    }

    func search(vector: [Float], level: PhaseLevel? = nil, topic: String? = nil, limit: Int = 3) throws -> [KnowledgeChunk] {
        try Self.validate(vector)
        guard limit > 0 else { return [] }
        guard !entries.isEmpty else { throw StoreError.emptyIndex }
        if let dimension, vector.count != dimension { throw StoreError.dimensionMismatch }
        return entries.enumerated().compactMap { index, entry -> (Int, KnowledgeChunk, Double)? in
            if let level, entry.chunk.level != level { return nil }
            if let topic, !entry.chunk.topic.localizedCaseInsensitiveContains(topic) { return nil }
            return (index, entry.chunk, Self.cosine(vector, entry.vector))
        }
        .sorted { $0.2 == $1.2 ? $0.0 < $1.0 : $0.2 > $1.2 }
        .prefix(limit)
        .map { $0.1 }
    }

    private static func validate(_ vector: [Float]) throws {
        guard !vector.isEmpty, vector.allSatisfy(\.isFinite),
              vector.contains(where: { $0 != 0 }) else { throw StoreError.invalidVector }
    }

    private static func cosine(_ left: [Float], _ right: [Float]) -> Double {
        var dot = 0.0
        var leftMagnitude = 0.0
        var rightMagnitude = 0.0
        for (lhs, rhs) in zip(left, right) {
            let a = Double(lhs)
            let b = Double(rhs)
            dot += a * b
            leftMagnitude += a * a
            rightMagnitude += b * b
        }
        return dot / (leftMagnitude.squareRoot() * rightMagnitude.squareRoot())
    }
}
