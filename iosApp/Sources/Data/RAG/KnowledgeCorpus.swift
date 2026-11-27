import Foundation

enum KnowledgeCorpus {
    struct Entry: Decodable {
        let path: String
        let level: PhaseLevel
        let topic: String
    }

    enum CorpusError: Error {
        case missingBundle
        case invalidPath(String)
        case emptyManifest
    }

    static func load(bundle: Bundle = .main) throws -> [KnowledgeChunk] {
        guard let root = bundle.url(forResource: "knowledge-base", withExtension: nil) else {
            throw CorpusError.missingBundle
        }
        return try load(root: root)
    }

    static func load(root: URL) throws -> [KnowledgeChunk] {
        let manifestURL = root.appendingPathComponent("manifest.json")
        let entries = try JSONDecoder().decode([Entry].self, from: Data(contentsOf: manifestURL))
        guard !entries.isEmpty else { throw CorpusError.emptyManifest }
        let base = root.standardizedFileURL.path
        return try entries.flatMap { entry in
            let url = root.appendingPathComponent(entry.path).standardizedFileURL
            guard url.path.hasPrefix(base + "/") else { throw CorpusError.invalidPath(entry.path) }
            return try DocumentParser.parse(url: url, level: entry.level, topic: entry.topic)
        }
    }
}
