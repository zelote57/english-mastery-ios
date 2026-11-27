import Foundation

extension Data {
    /// Decodes the JSON‑encoded embedding (array of Double) stored in a Chunk.
    func decodeEmbedding() throws -> [Double] {
        return try JSONDecoder().decode([Double].self, from: self)
    }
}
