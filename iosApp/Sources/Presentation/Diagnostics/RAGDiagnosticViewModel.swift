#if RAG_DIAGNOSTICS
import Foundation
import Observation

@Observable
@MainActor
final class RAGDiagnosticViewModel {
    var offlineConfirmed = false
    private(set) var isRunning = false
    private(set) var report: RAGDiagnosticReport?
    var errorMessage: String?

    func run() async {
        guard offlineConfirmed, !isRunning else { return }
        isRunning = true
        report = nil
        errorMessage = nil
        report = await RAGDiagnosticRunner().run(offlineConfirmed: true)
        isRunning = false
    }

    func exportData() -> Data? {
        guard let report else { return nil }
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            return try encoder.encode(report)
        } catch {
            errorMessage = "Unable to prepare the report for export."
            return nil
        }
    }
}
#endif
