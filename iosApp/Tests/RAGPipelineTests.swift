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
        let cases: [(skill: String, questionID: String, wrong: String, evidence: String)] = [
            ("A1-01", "8528b4b6-c30c-56d0-8414-24304e207431", "Me", "subject pronouns identify"),
            ("A1-02", "d73f7ea5-74cb-57c2-a5df-bd71fbb08fe0", "have", "when stating age"),
            ("A1-03", "a36061f8-1118-5587-bbcf-7f7341f14cb4", "a", "an apple"),
            ("A1-04", "871e661b-a9fd-5735-8e53-1a07f46b02cd", "boxs", "two boxes"),
            ("A1-05", "5bae8fc3-e37f-559e-9afc-25d553e38692", "go", "affirmative statements"),
            ("A2_INIT-01", "ce2f9a24-6d61-57d0-8315-f42e336ae3d9", "live", "Regular affirmative verbs"),
            ("A2_INIT-02", "19941540-3161-5e03-a4e4-c736517a13e7", "goed", "go/went"),
            ("A2_INIT-03", "f031e24a-42f4-5740-b701-acae869580a6", "since", "two days ago"),
            ("A2_INT-01", "a7aa537c-036e-54d6-954c-790f7510d479", "going to", "prediction based on present evidence"),
            ("A2_INT-02", "faeb809a-bf1f-562c-b1aa-f5056d06d067", "am going", "a decision made as you speak"),
            ("A2_INT-03", "c4ae8e35-8cf1-5cba-a059-613879a07306", "more fast", "faster than a bus"),
            ("A2_ADV-01", "20ecee91-86af-578d-a50a-24cdb4b6e926", "in", "with a clock time"),
            ("A2_ADV-02", "4ab4afe0-a0cb-5b69-adc6-d785c02fd5c2", "many", "uncountable nouns"),
            ("A2_ADV-03", "2ea564df-a7b1-590f-87e8-2dc68c455d08", "Can", "past ability"),
            ("B1_INIT-01", "946a7000-d93e-598b-930c-679315e5612e", "ago", "at any time"),
            ("B1_INIT-02", "2e01ee77-e9b5-5273-bf34-98f6a16f23d8", "for", "with a starting point"),
            ("B1_INIT-03", "135f730e-1a1a-563d-a542-751a8aab1321", "were", "I was reading"),
            ("B1_INT-01", "d011ed20-ee7e-5b09-83c1-e96576367973", "would", "possible future situation"),
            ("B1_INT-02", "2c42cd0c-dc31-5f77-a8a1-3629f588e5ee", "is", "novel was written"),
            ("B1_INT-03", "8457b852-e2d4-5aa3-9e26-cdbf8c29196e", "to read", "enjoy reading"),
            ("B1_ADV-01", "5790b56d-4019-51f4-8c29-a1136b2d0ddb", "are", "she was tired"),
            ("B1_ADV-02", "d04c9cab-5261-5610-8624-212b3010a4d2", "must", "something is impossible"),
            ("B1_ADV-03", "50d4f88f-f740-5fc8-bdf2-1f5fc31f8870", "take off", "stop trying"),
            ("B2_INIT-01", "16bda85a-06e8-564d-a9cc-605abd57a8b5", "wouldn't", "would have + past participle"),
            ("B2_INIT-02", "e3da1c02-dfad-5c50-aa8d-95e9ee6b45c0", "who's", "whose car was towed"),
            ("B2_INIT-03", "6ccea60d-e615-5881-82ca-88c30470b3ff", "live", "present situation were different"),
            ("B2_ADV-01", "7fdba315-0a9c-5c1c-b030-f24f9653efbe", "so boring", "such a boring film"),
            ("B2_ADV-02", "2bcd2270-53dd-544f-ac79-1198b03949e6", "do", "make a decision"),
            ("B2_ADV-03", "6b10323e-c394-5105-9dc9-baedd26d1849", "furthermore", "introduce contrast"),
            ("A1-04", "29a544a9-e0ae-5637-8d10-c5b72f7ed1da", "city", "city, cities"),
            ("A2_ADV-02", "27c2455e-3b94-54db-995c-6c36d74a355e", "some", "questions and negatives"),
            ("B1_INT-03", "c2cb17b0-4371-5713-974d-aa26e0d7d16b", "accepting", "decide to leave"),
            ("B1_ADV-01", "f67854fb-a621-5acb-b076-50e742935612", "will", "will** to **would"),
            ("B2_INIT-03", "1c164cc5-dc96-5c4c-b812-f86fe3f682b2", "didn't spend", "regret about a past situation"),
            ("B2_ADV-01", "66dc0973-460c-5bd1-8bfa-03a65190255a", "Although", "In spite of the rain"),
            ("B2_ADV-03", "dd63cb5c-9b7a-5424-9710-dd457e7c8304", "Although", "introduces a noun phrase")
        ]
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
}

private struct TestEmbedding: EmbeddingProvider {
    func embed(_ text: String) async throws -> [Float] {
        text.localizedCaseInsensitiveContains("preposition") ? [1, 0] : [0, 1]
    }
}
