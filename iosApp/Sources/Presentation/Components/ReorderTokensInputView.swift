import SwiftUI

/// Interactive word-bank and sentence-builder chip trays for `.reorder` questions.
struct ReorderTokensInputView: View {
    let controller: QuestionInputController

    private var selectedIds: Set<Int> {
        Set(controller.selectedTokens.map(\.id))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            selectedTray
            wordBankGrid
        }
        .sensoryFeedback(.selection, trigger: controller.selectedTokens)
    }

    private var selectedTray: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Your sentence")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                if !controller.selectedTokens.isEmpty {
                    Button("Clear") { controller.clearReorderSelection() }
                        .font(.caption.weight(.semibold))
                }
            }
            if controller.selectedTokens.isEmpty {
                Text("Tap words below to build the sentence")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
                    .padding(12)
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
            } else {
                tokenGrid(tokens: controller.selectedTokens, isSelectedTray: true) { token in
                    controller.removeSelectedToken(token)
                }
                .padding(8)
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    private var wordBankGrid: some View {
        tokenGrid(
            tokens: controller.availableTokens.filter { !selectedIds.contains($0.id) },
            isSelectedTray: false
        ) { token in
            controller.selectToken(token)
        }
    }

    private func tokenGrid(
        tokens: [ReorderToken],
        isSelectedTray: Bool,
        action: @escaping (ReorderToken) -> Void
    ) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 84), spacing: 8)], spacing: 8) {
            ForEach(tokens) { token in
                Button {
                    action(token)
                } label: {
                    Text(token.text)
                        .font(.subheadline.weight(.medium))
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .padding(.horizontal, 8)
                }
                .buttonStyle(.bordered)
                .tint(isSelectedTray ? .blue : .primary)
                .accessibilityLabel(token.text)
                .accessibilityHint(isSelectedTray ? "Removes word from sentence" : "Adds word to sentence")
            }
        }
    }
}
