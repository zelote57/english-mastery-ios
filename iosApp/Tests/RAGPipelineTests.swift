import PDFKit
import SwiftData
import UIKit
import XCTest
@testable import EnglishMastery

@MainActor
final class RAGPipelineTests: XCTestCase {
    func testBundledCorpusLoadsMetadataAndCanBeSearched() async throws {
        let chunks = try KnowledgeCorpus.load()
        XCTAssertTrue(chunks.contains { $0.level == .a1 && $0.topic == "Verb \"to be\"" })
        XCTAssertTrue(chunks.contains { $0.level == .a2Adv && $0.topic.contains("Prepositions") })
        XCTAssertTrue(chunks.allSatisfy { !$0.content.isEmpty && !$0.sourceFile.isEmpty })

        let index = KnowledgeIndex(embedding: TestEmbedding())
        try await index.index(chunks)
        let results = try await index.search("prepositions", level: .a2Adv, topic: "prepositions")
        XCTAssertFalse(results.isEmpty)
        XCTAssertTrue(results.allSatisfy { $0.level == .a2Adv && $0.topic.contains("Prepositions") })
    }

    func testBundledTopicsMatchSeededSkills() async throws {
        let container = try DataLayer.makeModelContainer(inMemory: true)
        try CurriculumSeeder.seedIfNeeded(in: container.mainContext)
        let skills = try container.mainContext.fetch(FetchDescriptor<SkillModel>())
        let phases = try container.mainContext.fetch(FetchDescriptor<PhaseModel>())
        let chunks = try KnowledgeCorpus.load()
        let index = KnowledgeIndex(embedding: TestEmbedding())
        try await index.index(chunks)
        XCTAssertEqual(skills.count, 29)
        for skill in skills {
            let phase = try XCTUnwrap(phases.first { $0.id == skill.phaseId }?.toDomain())
            let results = try await index.search(skill.topic, level: phase.level, topic: skill.topic)
            XCTAssertFalse(results.isEmpty, "Missing indexed topic for \(skill.skillCode): \(skill.topic)")
            XCTAssertTrue(
                results.allSatisfy { $0.level == phase.level && $0.topic == skill.topic },
                "Unexpected topic for \(skill.skillCode): \(results.map(\.topic))"
            )
        }
        XCTAssertTrue(chunks.contains { $0.sourceFile == "spanish-interference/structural-errors.md" })
        XCTAssertTrue(chunks.contains { $0.sourceFile == "spanish-interference/false-friends.md" })
        XCTAssertTrue(chunks.contains {
            $0.topic == "Prepositions of place/time" && $0.content.localizedCaseInsensitiveContains("marry someone")
        })
        let prepositionSources = Set(chunks.filter { $0.topic == "Prepositions of place/time" }.map(\.sourceFile))
        XCTAssertEqual(prepositionSources, [
            "grammar-rules/A2/prepositions.md", "spanish-interference/prepositions.md"
        ])
    }

    func testPromptTemplatesIncludeGroundingAndOutputContract() throws {
        let root = try XCTUnwrap(Bundle.main.url(forResource: "knowledge-base", withExtension: nil))
        let names = ["grammar-correction", "vocabulary-confusion", "preposition-error", "word-order"]
        let required = [
            "{level}", "{skill_topic}", "{user_answer}", "{correct_answer}", "{question}", "{rag_chunks}",
            "### 💡 ¿Por qué no es correcta?", "### 📘 Regla clave", "### 🔍 Ejemplos prácticos",
            "fewer than 150 words"
        ]
        for name in names {
            let url = root.appendingPathComponent("prompt-templates").appendingPathComponent("\(name).md")
            let text = try String(contentsOf: url, encoding: .utf8)
            for value in required {
                XCTAssertTrue(text.contains(value), "\(name) is missing \(value)")
            }
        }
    }

    func testChunkingPreservesParagraphsAndMetadata() {
        let first = Array(repeating: "first", count: 160).joined(separator: " ")
        let second = Array(repeating: "second", count: 160).joined(separator: " ")
        let chunks = DocumentChunker.split(
            "\(first)\n\n\(second)", sourceFile: "sample.md", level: .b2Adv, topic: "Grammar"
        )
        XCTAssertEqual(chunks.count, 2)
        XCTAssertEqual(chunks.map(\.chunkIndex), [0, 1])
        XCTAssertEqual(chunks.map(\.content), [first, second])
        XCTAssertTrue(chunks.allSatisfy { $0.level == .b2Adv && $0.topic == "Grammar" })
        XCTAssertTrue(DocumentChunker.split("", sourceFile: "empty", level: .a1, topic: "Grammar").isEmpty)

        let longSentence = Array(repeating: "word", count: 500).joined(separator: " ")
        let split = DocumentChunker.split(longSentence, sourceFile: "long.md", level: .a1, topic: "Grammar")
        XCTAssertEqual(split.map { $0.content.split(separator: " ").count }, [225, 225, 50])
        XCTAssertEqual(split.map(\.content).joined(separator: " "), longSentence)
    }

    func testPDFExtractionAndInvalidDocuments() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("rule.pdf")
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 300, height: 300))
        let data = renderer.pdfData { context in
            context.beginPage()
            ("English grammar example" as NSString).draw(
                at: CGPoint(x: 20, y: 20), withAttributes: [.font: UIFont.systemFont(ofSize: 14)]
            )
        }
        try data.write(to: url)
        let chunks = try DocumentParser.parse(url: url, level: .b1Init, topic: "Grammar")
        XCTAssertTrue(chunks[0].content.contains("English grammar example"))
        XCTAssertEqual(chunks[0].level, .b1Init)

        let invalid = directory.appendingPathComponent("invalid.pdf")
        try Data("not a PDF".utf8).write(to: invalid)
        XCTAssertThrowsError(try DocumentParser.parse(url: invalid, level: .a1, topic: "Grammar"))
    }

    func testCosineRankingFilteringAndInvalidVectors() async throws {
        let store = VectorStore()
        let chunks = [
            KnowledgeChunk(sourceFile: "a", content: "exact", level: .a1, topic: "Grammar", chunkIndex: 0),
            KnowledgeChunk(sourceFile: "b", content: "close", level: .a1, topic: "Grammar", chunkIndex: 0),
            KnowledgeChunk(sourceFile: "c", content: "other", level: .b1Init, topic: "Vocabulary", chunkIndex: 0)
        ]
        try await store.replace(with: [
            IndexedChunk(chunk: chunks[0], vector: [1, 0]),
            IndexedChunk(chunk: chunks[1], vector: [1, 1]),
            IndexedChunk(chunk: chunks[2], vector: [0, 1])
        ])
        let ranked = try await store.search(vector: [1, 0])
        XCTAssertEqual(ranked.map(\.content), ["exact", "close", "other"])
        let filtered = try await store.search(vector: [1, 0], level: .a1, topic: "grammar")
        XCTAssertEqual(filtered.count, 2)
        do {
            try await store.replace(with: [IndexedChunk(chunk: chunks[0], vector: [0, 0])])
            XCTFail("Zero vectors must be rejected")
        } catch {
            XCTAssertEqual(error as? VectorStore.StoreError, .invalidVector)
        }
        let afterFailure = try await store.search(vector: [1, 0])
        XCTAssertEqual(afterFailure.count, 3)
        do {
            _ = try await store.search(vector: [1, 0, 0])
            XCTFail("Mismatched dimensions must be rejected")
        } catch {
            XCTAssertEqual(error as? VectorStore.StoreError, .dimensionMismatch)
        }
    }

    func testExactTopicDoesNotMatchLongerTopicContainingItsName() async throws {
        let store = VectorStore()
        let regular = KnowledgeChunk(
            sourceFile: "regular", content: "regular", level: .a2Init,
            topic: "Regular past simple", chunkIndex: 0
        )
        let irregular = KnowledgeChunk(
            sourceFile: "irregular", content: "irregular", level: .a2Init,
            topic: "Irregular past simple", chunkIndex: 0
        )
        try await store.replace(with: [
            IndexedChunk(chunk: regular, vector: [1, 0]),
            IndexedChunk(chunk: irregular, vector: [1, 0])
        ])
        let exact = try await store.search(vector: [1, 0], level: .a2Init, topic: "regular past simple")
        XCTAssertEqual(exact.map(\.topic), ["Regular past simple"])
        let partial = try await store.search(vector: [1, 0], level: .a2Init, topic: "past simple")
        XCTAssertEqual(Set(partial.map(\.topic)), Set(["Regular past simple", "Irregular past simple"]))
    }

    func testNativeEnglishEmbeddingWhenAvailable() async throws {
        let provider = NaturalLanguageEmbedding()
        do {
            let vector = try await provider.embed("English grammar lesson")
            XCTAssertTrue((128...512).contains(vector.count))
            XCTAssertTrue(vector.allSatisfy(\.isFinite))
            XCTAssertTrue(vector.contains { $0 != 0 })
        } catch NaturalLanguageEmbedding.EmbeddingError.unavailable {
            throw XCTSkip("English word embeddings are not available on this simulator.")
        }

    }

    func testNativeEmbeddingSearchesBundledTopicWhenAvailable() async throws {
        let index = KnowledgeIndex()
        do {
            try await index.index(KnowledgeCorpus.load())
            let results = try await index.search("verb to be grammar", level: .a1, topic: "Verb \"to be\"")
            XCTAssertFalse(results.isEmpty)
            XCTAssertTrue(results.allSatisfy { $0.topic == "Verb \"to be\"" })
            let prepositions = try await index.search(
                "Grammar rule for prepositions and error depends of instead of depends on",
                level: .a2Adv, topic: "Prepositions of place/time"
            )
            XCTAssertTrue(prepositions.contains { $0.content.localizedCaseInsensitiveContains("depend") })
            let cases: [(PhaseLevel, String, String, String)] = [
                (.a1, "Personal pronouns", "Me work here instead of I work here", "subject"),
                (.a2Init, "Regular past simple", "She studyed instead of she studied yesterday", "studied"),
                (.a2Int, "Comparatives and superlatives", "more fast instead of faster", "faster"),
                (.b1Init, "for vs since", "since three years instead of for three years", "for three years"),
                (.b1Int, "Gerunds vs infinitives", "I enjoy to read instead of I enjoy reading", "enjoy"),
                (.b1Adv, "Reported speech", "She said me instead of she told me", "told me"),
                (.b2Init, "wish / if only", "I wish I have more time instead of I wish I had more time", "wish"),
                (.b2Adv, "Advanced collocations", "make attention instead of pay attention", "attention")
            ]
            for (level, topic, query, expected) in cases {
                let results = try await index.search(query, level: level, topic: topic)
                XCTAssertTrue(
                    results.contains { $0.content.localizedCaseInsensitiveContains(expected) },
                    "No relevant top-three chunk for \(topic)"
                )
            }
        } catch NaturalLanguageEmbedding.EmbeddingError.unavailable {
            throw XCTSkip("English word embeddings are not available on this simulator.")
        }
    }

    func testNativeRetrievalRelevanceForSeededMistakes() async throws {
        let cases = RAGBenchmark.cases
        let container = try DataLayer.makeModelContainer(inMemory: true)
        try CurriculumSeeder.seedIfNeeded(in: container.mainContext)
        let skills = try container.mainContext.fetch(FetchDescriptor<SkillModel>())
        let phases = try container.mainContext.fetch(FetchDescriptor<PhaseModel>())
        let questions = try container.mainContext.fetch(FetchDescriptor<QuestionModel>())
        XCTAssertEqual(Set(cases.map(\.skill)), Set(skills.map(\.skillCode)))

        let index = KnowledgeIndex()
        try await index.index(KnowledgeCorpus.load())
        var topOne = 0
        var topThree = 0
        for item in cases {
            let skill = try XCTUnwrap(skills.first { $0.skillCode == item.skill })
            let phase = try XCTUnwrap(phases.first { $0.id == skill.phaseId }?.toDomain())
            let id = try XCTUnwrap(UUID(uuidString: item.questionID))
            let question = try XCTUnwrap(questions.first { $0.id == id }?.toDomain())
            XCTAssertEqual(question.skillId, skill.id, item.questionID)
            XCTAssertEqual(ScoringEngine.grade(answer: item.wrong, for: question).pointsEarned, 0, item.questionID)
            let query = "Grammar rule for \(skill.topic) and error: \(item.wrong) instead of \(question.correctAnswer)"
            let results = try await index.search(query, level: phase.level, topic: skill.topic)
            let rank = results.firstIndex { $0.content.localizedCaseInsensitiveContains(item.evidence) }
            if rank == 0 { topOne += 1 }
            if rank != nil { topThree += 1 }
            XCTAssertNotNil(rank, "\(item.skill): missing '\(item.evidence)' in top three for \(item.questionID)")
        }
        print("RAG relevance: top-1 \(topOne)/\(cases.count), top-3 \(topThree)/\(cases.count)")
        XCTAssertEqual(topThree, cases.count)
    }

    func testDiagnosticReportUsesSharedBenchmarkAndExportsOnlyDiagnosticData() async throws {
        let report = await RAGDiagnosticRunner().run(offlineConfirmed: true)
        XCTAssertEqual(report.results.count, RAGBenchmark.cases.count)
        XCTAssertEqual(report.topThree, RAGBenchmark.cases.count)
        XCTAssertNotNil(report.indexingMilliseconds)
        XCTAssertNotNil(report.averageQueryMilliseconds)
        XCTAssertNotNil(report.maximumSampledResidentBytes)
        XCTAssertEqual(report.errors.filter { $0 != "Build commit is missing or invalid" }, [])
        let data = try JSONEncoder().encode(report)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(json["expectedCases"] as? Int, 36)
        XCTAssertEqual(json["topThree"] as? Int, 36)
        XCTAssertEqual(json["offlineConfirmedByUser"] as? Bool, true)
        let results = try XCTUnwrap(json["results"] as? [[String: Any]])
        XCTAssertEqual(Set(results.compactMap { $0["questionID"] as? String }), Set(RAGBenchmark.cases.map(\.questionID)))
        XCTAssertTrue(results.allSatisfy { $0["rank"] != nil && $0["durationMilliseconds"] != nil })
        XCTAssertTrue(results.allSatisfy { $0["userAnswer"] == nil && $0["correctAnswer"] == nil })
    }

    func testDiagnosticReportExposesEmbeddingFailureAndUnconfirmedOfflineState() async throws {
        let report = await RAGDiagnosticRunner(embedding: FailingTestEmbedding()).run(offlineConfirmed: false)
        XCTAssertFalse(report.passed)
        XCTAssertTrue(report.results.isEmpty)
        XCTAssertTrue(report.errors.contains("Offline condition not confirmed by user"))
        XCTAssertTrue(report.errors.contains { $0.contains("Benchmark setup failed") })
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(report)) as? [String: Any])
        XCTAssertEqual(json["passed"] as? Bool, false)
        XCTAssertEqual(json["offlineConfirmedByUser"] as? Bool, false)
    }
}

private struct TestEmbedding: EmbeddingProvider {
    func embed(_ text: String) async throws -> [Float] {
        text.localizedCaseInsensitiveContains("preposition") ? [1, 0] : [0, 1]
    }
}

private struct FailingTestEmbedding: EmbeddingProvider {
    enum Failure: Error { case unavailable }

    func embed(_ text: String) async throws -> [Float] {
        throw Failure.unavailable
    }
}
