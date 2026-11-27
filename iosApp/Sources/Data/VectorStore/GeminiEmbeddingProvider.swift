// GeminiEmbeddingProvider.swift
// Pure‑Swift stub embedding provider.
// No external SDK required; returns a deterministic vector based on character values.
// Replace this with a real on‑device model when the SDK is integrated via XcodeGen.

import Foundation

/// Generates a simple bag‑of‑characters embedding (sum of UTF‑8 scalar values per token).
/// This is a deterministic placeholder that lets the RAG pipeline compile and run without
/// any external dependency. Swap `embed(_:)` for a real model call when ready.
public struct GeminiEmbeddingProvider {
    public init() {}

    /// Returns a JSON‑encoded `[Double]` representing the input text.
    public func embed(_ text: String) async throws -> Data {
        let vector = naiveEmbed(text)
        return try JSONEncoder().encode(vector)
    }

    // MARK: - Private
    private func naiveEmbed(_ text: String) -> [Double] {
        // 64‑dimensional vector: each bucket accumulates scalar values for characters
        // mapped to that bucket modulo 64.
        var vec = [Double](repeating: 0, count: 64)
        for scalar in text.unicodeScalars {
            let idx = Int(scalar.value) % 64
            vec[idx] += Double(scalar.value)
        }
        // L2‑normalise.
        let norm = sqrt(vec.reduce(0) { $0 + $1 * $1 })
        return norm > 0 ? vec.map { $0 / norm } : vec
    }
}
