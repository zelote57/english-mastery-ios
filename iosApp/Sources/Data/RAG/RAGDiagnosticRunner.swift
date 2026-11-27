import CryptoKit
import Darwin
import Foundation

struct RAGDiagnosticReport: Encodable, Sendable {
    struct CaseResult: Encodable, Sendable {
        let skill: String
        let questionID: String
        let rank: Int?
        let durationMilliseconds: Double?
        let error: String?
    }

    let schemaVersion = 1
    let benchmarkVersion = RAGBenchmark.version
    let commit: String
    let appVersion: String
    let deviceModel: String
    let osVersion: String
    let offlineConfirmedByUser: Bool
    let timestamp: String
    let expectedCases = RAGBenchmark.cases.count
    let memoryMethod = "mach_task_basic_info resident_size; maximum sampled between queries, bytes"
    var curriculumVersion: Int?
    var manifestSHA256: String?
    var indexingMilliseconds: Double?
    var maximumSampledResidentBytes: UInt64?
    var results: [CaseResult] = []
    var errors: [String] = []

    var topOne: Int { results.filter { $0.rank == 1 }.count }
    var topThree: Int { results.filter { $0.rank != nil }.count }
    var averageQueryMilliseconds: Double? {
        let times = results.compactMap(\.durationMilliseconds)
        return times.isEmpty ? nil : times.reduce(0, +) / Double(times.count)
    }
    var passed: Bool {
        errors.isEmpty && results.count == expectedCases && topThree == expectedCases
    }

    enum CodingKeys: String, CodingKey {
        case schemaVersion, benchmarkVersion, commit, appVersion, deviceModel, osVersion
        case offlineConfirmedByUser, timestamp, expectedCases, memoryMethod, curriculumVersion
        case manifestSHA256, indexingMilliseconds, maximumSampledResidentBytes, results, errors
        case topOne, topThree, averageQueryMilliseconds, passed
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(schemaVersion, forKey: .schemaVersion)
        try container.encode(benchmarkVersion, forKey: .benchmarkVersion)
        try container.encode(commit, forKey: .commit)
        try container.encode(appVersion, forKey: .appVersion)
        try container.encode(deviceModel, forKey: .deviceModel)
        try container.encode(osVersion, forKey: .osVersion)
        try container.encode(offlineConfirmedByUser, forKey: .offlineConfirmedByUser)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encode(expectedCases, forKey: .expectedCases)
        try container.encode(memoryMethod, forKey: .memoryMethod)
        try container.encode(curriculumVersion, forKey: .curriculumVersion)
        try container.encode(manifestSHA256, forKey: .manifestSHA256)
        try container.encode(indexingMilliseconds, forKey: .indexingMilliseconds)
        try container.encode(maximumSampledResidentBytes, forKey: .maximumSampledResidentBytes)
        try container.encode(results, forKey: .results)
        try container.encode(errors, forKey: .errors)
        try container.encode(topOne, forKey: .topOne)
        try container.encode(topThree, forKey: .topThree)
        try container.encode(averageQueryMilliseconds, forKey: .averageQueryMilliseconds)
        try container.encode(passed, forKey: .passed)
    }
}

actor RAGDiagnosticRunner {
    private struct Seed: Decodable {
        struct Phase: Decodable {
            let id: UUID
            let level: PhaseLevel
        }
        struct Skill: Decodable {
            let id: UUID
            let skillCode: String
            let topic: String
            let phaseId: UUID
        }
        let version: Int
        let phases: [Phase]
        let skills: [Skill]
        let questions: [Question]
    }

    private enum DiagnosticError: Error {
        case missingSeed
        case missingManifest
        case invalidBenchmark
    }

    private let index: KnowledgeIndex

    init(embedding: any EmbeddingProvider = NaturalLanguageEmbedding()) {
        index = KnowledgeIndex(embedding: embedding)
    }

    func run(offlineConfirmed: Bool, bundle: Bundle = .main) async -> RAGDiagnosticReport {
        let commit = bundle.object(forInfoDictionaryKey: "RAGBuildCommit") as? String ?? "unavailable"
        var report = RAGDiagnosticReport(
            commit: commit,
            appVersion: bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unavailable",
            deviceModel: Self.deviceModel(),
            osVersion: ProcessInfo.processInfo.operatingSystemVersionString,
            offlineConfirmedByUser: offlineConfirmed,
            timestamp: ISO8601DateFormatter().string(from: Date())
        )
        if !offlineConfirmed { report.errors.append("Offline condition not confirmed by user") }
        if commit.count != 40 || !commit.allSatisfy(\.isHexDigit) {
            report.errors.append("Build commit is missing or invalid")
        }
        if report.deviceModel == "unavailable" { report.errors.append("Device model unavailable") }
        sampleMemory(into: &report)

        do {
            guard let seedURL = bundle.url(forResource: "seed-curriculum", withExtension: "json") else {
                throw DiagnosticError.missingSeed
            }
            let seed = try JSONDecoder().decode(Seed.self, from: Data(contentsOf: seedURL))
            report.curriculumVersion = seed.version
            guard Set(RAGBenchmark.cases.map(\.skill)) == Set(seed.skills.map(\.skillCode)),
                  Set(RAGBenchmark.cases.map(\.questionID)).count == RAGBenchmark.cases.count else {
                throw DiagnosticError.invalidBenchmark
            }
            guard let root = bundle.url(forResource: "knowledge-base", withExtension: nil) else {
                throw DiagnosticError.missingManifest
            }
            let manifest = try Data(contentsOf: root.appendingPathComponent("manifest.json"))
            report.manifestSHA256 = SHA256.hash(data: manifest).map { String(format: "%02x", $0) }.joined()
            let start = ProcessInfo.processInfo.systemUptime
            try await index.index(KnowledgeCorpus.load(bundle: bundle))
            report.indexingMilliseconds = (ProcessInfo.processInfo.systemUptime - start) * 1_000
            sampleMemory(into: &report)

            for item in RAGBenchmark.cases {
                guard let skill = seed.skills.first(where: { $0.skillCode == item.skill }),
                      let phase = seed.phases.first(where: { $0.id == skill.phaseId }),
                      let id = UUID(uuidString: item.questionID),
                      let question = seed.questions.first(where: { $0.id == id }),
                      question.skillId == skill.id,
                      ScoringEngine.grade(answer: item.wrong, for: question).pointsEarned == 0 else {
                    report.results.append(.init(
                        skill: item.skill, questionID: item.questionID, rank: nil,
                        durationMilliseconds: nil, error: "Invalid benchmark case"
                    ))
                    report.errors.append("Invalid benchmark case: \(item.questionID)")
                    continue
                }
                let query = "Grammar rule for \(skill.topic) and error: \(item.wrong) instead of \(question.correctAnswer)"
                let start = ProcessInfo.processInfo.systemUptime
                do {
                    let chunks = try await index.search(query, level: phase.level, topic: skill.topic)
                    let duration = (ProcessInfo.processInfo.systemUptime - start) * 1_000
                    let rank = chunks.firstIndex { $0.content.localizedCaseInsensitiveContains(item.evidence) }
                        .map { $0 + 1 }
                    report.results.append(.init(
                        skill: item.skill, questionID: item.questionID, rank: rank,
                        durationMilliseconds: duration, error: rank == nil ? "Expected rule not in top three" : nil
                    ))
                } catch {
                    report.results.append(.init(
                        skill: item.skill, questionID: item.questionID, rank: nil,
                        durationMilliseconds: (ProcessInfo.processInfo.systemUptime - start) * 1_000,
                        error: "Retrieval error: \(String(reflecting: type(of: error)))"
                    ))
                    report.errors.append("Retrieval failed: \(item.questionID)")
                }
                sampleMemory(into: &report)
            }
        } catch {
            report.errors.append("Benchmark setup failed: \(String(reflecting: type(of: error)))")
        }
        return report
    }

    private func sampleMemory(into report: inout RAGDiagnosticReport) {
        var info = mach_task_basic_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info_data_t>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        guard result == KERN_SUCCESS else {
            if !report.errors.contains("Resident memory measurement unavailable") {
                report.errors.append("Resident memory measurement unavailable")
            }
            return
        }
        report.maximumSampledResidentBytes = max(report.maximumSampledResidentBytes ?? 0, info.resident_size)
    }

    private static func deviceModel() -> String {
        var info = utsname()
        guard uname(&info) == 0 else { return "unavailable" }
        let capacity = MemoryLayout.size(ofValue: info.machine)
        return withUnsafePointer(to: &info.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: capacity) {
                String(cString: $0)
            }
        }
    }
}
