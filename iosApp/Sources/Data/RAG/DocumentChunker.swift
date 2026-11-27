import Foundation
import NaturalLanguage

enum DocumentChunker {
    static func split(
        _ text: String, sourceFile: String, level: PhaseLevel, topic: String, targetWords: Int = 225
    ) -> [KnowledgeChunk] {
        guard targetWords > 0 else { return [] }
        let normalized = text.replacingOccurrences(of: "\r\n", with: "\n")
        let paragraphs = normalized.components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        var groups: [String] = []
        var current: [String] = []
        var count = 0

        for paragraph in paragraphs {
            let sentences = wordCount(paragraph) > targetWords ? sentences(in: paragraph) : [paragraph]
            let units = sentences.flatMap { sentence in
                wordCount(sentence) > targetWords ? splitLongSentence(sentence, limit: targetWords) : [sentence]
            }
            for unit in units {
                let words = wordCount(unit)
                if !current.isEmpty && count + words > targetWords {
                    groups.append(current.joined(separator: "\n\n"))
                    current = []
                    count = 0
                }
                current.append(unit)
                count += words
            }
        }
        if !current.isEmpty { groups.append(current.joined(separator: "\n\n")) }
        return groups.enumerated().map { index, content in
            KnowledgeChunk(sourceFile: sourceFile, content: content, level: level, topic: topic, chunkIndex: index)
        }
    }

    private static func wordCount(_ text: String) -> Int {
        let tokenizer = NLTokenizer(unit: .word)
        tokenizer.string = text
        var count = 0
        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { _, _ in
            count += 1
            return true
        }
        return count
    }

    private static func sentences(in text: String) -> [String] {
        let tokenizer = NLTokenizer(unit: .sentence)
        tokenizer.string = text
        var result: [String] = []
        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { range, _ in
            let sentence = String(text[range]).trimmingCharacters(in: .whitespacesAndNewlines)
            if !sentence.isEmpty { result.append(sentence) }
            return true
        }
        return result.isEmpty ? [text] : result
    }

    private static func splitLongSentence(_ text: String, limit: Int) -> [String] {
        let tokenizer = NLTokenizer(unit: .word)
        tokenizer.string = text
        var result: [String] = []
        var start = text.startIndex
        var count = 0
        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { range, _ in
            if count == limit {
                result.append(String(text[start..<range.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines))
                start = range.lowerBound
                count = 0
            }
            count += 1
            return true
        }
        let remainder = String(text[start...]).trimmingCharacters(in: .whitespacesAndNewlines)
        if !remainder.isEmpty { result.append(remainder) }
        return result
    }
}
