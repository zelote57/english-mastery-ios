import Foundation
#if canImport(GenerativeAI)
import GenerativeAI

/// Simple provider that uses the Gemini on‑device API to generate text embeddings.
/// The returned value is a JSON‑encoded `Data` representing an array of `Double`.
public struct GeminiEmbeddingProvider {
    private let model: GenerativeModel
    
    public init() {
        // Gemini‑1.5‑flash‑embed is a hypothetical on‑device embedding model.
        self.model = GenerativeModel(name: "gemini-1.5-flash-embed")
    }
    
    /// Generates an embedding for the given text.
    /// - Parameter text: Input string to embed.
    /// - Returns: JSON‑encoded `Data` containing an array of `Double` values.
    public func embed(_ text: String) async throws -> Data {
        let response = try await model.embed(contentsOf: [text])
        let embedding = response.values.first ?? []
        return try JSONEncoder().encode(embedding)
    }
}
#else
/// Fallback stub implementation when the GenerativeAI SDK is unavailable.
/// Returns a deterministic simple embedding (vector with a single element = text length).
public struct GeminiEmbeddingProvider {
    public init() {}
    public func embed(_ text: String) async throws -> Data {
        let vec = [Double(text.count)]
        return try JSONEncoder().encode(vec)
    }
}
#endif

/// Simple provider that uses the Gemini on‑device API to generate text embeddings.
/// The returned value is a JSON‑encoded `Data` representing an array of `Double`.
public struct GeminiEmbeddingProvider {
    private let model: GenerativeModel
    
    public init() {
        // Gemini‑1.5‑flash‑embed is a hypothetical on‑device embedding model.
        // The SDK uses `GenerativeModel(name:)` where the name can refer to an embedder.
        self.model = GenerativeModel(name: "gemini-1.5-flash-embed")
    }
    
    /// Generates an embedding for the given text.
    /// - Parameter text: Input string to embed.
    /// - Returns: JSON‑encoded `Data` containing an array of `Double` values.
    public func embed(_ text: String) async throws -> Data {
        // The SDK method `embed(contentsOf:)` returns an `EmbeddingResponse` with a `values` property.
        let response = try await model.embed(contentsOf: [text])
        // Assume `response` has a `values` property of type `[Double]`.
        let embedding = response.values.first ?? []
        let json = try JSONEncoder().encode(embedding)
        return json
    }
}
