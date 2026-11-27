#if RAG_DIAGNOSTICS
import SwiftUI
import UniformTypeIdentifiers

struct RAGDiagnosticView: View {
    @State private var model = RAGDiagnosticViewModel()
    @State private var exportDocument: RAGReportDocument?
    @State private var showingExporter = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Offline test") {
                    Text("Enable airplane mode and turn off Wi-Fi and cellular data before running.")
                    Toggle("I confirmed the device is offline", isOn: $model.offlineConfirmed)
                        .disabled(model.isRunning)
                    Button("Run Diagnostic") {
                        Task { await model.run() }
                    }
                    .disabled(!model.offlineConfirmed || model.isRunning)
                    if model.isRunning {
                        ProgressView("Running retrieval benchmark...")
                    }
                }
                if let report = model.report {
                    RAGDiagnosticResultsView(report: report)
                    Button("Export JSON Report") {
                        if let data = model.exportData() {
                            exportDocument = RAGReportDocument(data: data)
                            showingExporter = true
                        }
                    }
                }
                if let error = model.errorMessage {
                    Text(error).foregroundStyle(.red)
                }
            }
            .navigationTitle("RAG Diagnostic")
            .fileExporter(
                isPresented: $showingExporter, document: exportDocument,
                contentType: .json, defaultFilename: "rag-diagnostic-report"
            ) { result in
                if case .failure = result {
                    model.errorMessage = "Unable to save the report. Please try again."
                }
            }
        }
    }
}

private struct RAGDiagnosticResultsView: View {
    let report: RAGDiagnosticReport

    var body: some View {
        Section("Results") {
            LabeledContent("Status", value: report.passed ? "Passed" : "Needs review")
            LabeledContent("Top 1", value: "\(report.topOne) / \(report.expectedCases)")
            LabeledContent("Top 3", value: "\(report.topThree) / \(report.expectedCases)")
            LabeledContent("Completed", value: "\(report.results.count) / \(report.expectedCases)")
            if let time = report.indexingMilliseconds {
                LabeledContent("Indexing", value: "\(time.formatted(.number.precision(.fractionLength(1)))) ms")
            }
            if let time = report.averageQueryMilliseconds {
                LabeledContent("Average query", value: "\(time.formatted(.number.precision(.fractionLength(1)))) ms")
            }
            if let memory = report.maximumSampledResidentBytes {
                LabeledContent("Sampled memory", value: ByteCountFormatter.string(fromByteCount: Int64(memory), countStyle: .memory))
            }
            ForEach(report.errors, id: \.self) { error in
                Text(error).foregroundStyle(.red)
            }
            ForEach(report.results.filter { $0.error != nil }, id: \.questionID) { result in
                Text("\(result.skill): \(result.error ?? "")").foregroundStyle(.red)
            }
        }
    }
}

private struct RAGReportDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    let data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.data = data
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
#endif
