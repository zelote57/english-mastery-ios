import SwiftUI

/// Renders the question prompt card and type-appropriate input controls across tests.
struct QuestionInputView: View {
    let question: Question
    let controller: QuestionInputController
    let onSubmit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(controller.displayPrompt)
                .font(.title3.weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)

            switch question.questionType {
            case .multipleChoice:
                MultipleChoiceOptionsView(controller: controller)
            case .fillBlank, .translation:
                TextAnswerInputView(controller: controller, onSubmit: onSubmit)
            case .reorder:
                ReorderTokensInputView(controller: controller)
            }
        }
    }
}

private struct MultipleChoiceOptionsView: View {
    let controller: QuestionInputController

    var body: some View {
        VStack(spacing: 12) {
            ForEach(controller.multipleChoiceOptions, id: \.self) { option in
                let isSelected = controller.selectedChoice == option
                Button {
                    controller.selectedChoice = option
                } label: {
                    HStack {
                        Text(option)
                            .font(.body)
                            .multilineTextAlignment(.leading)
                        Spacer()
                        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(isSelected ? .blue : .secondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        isSelected ? Color.blue.opacity(0.12) : Color(.secondarySystemBackground),
                        in: RoundedRectangle(cornerRadius: 12)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
                    )
                }
                .buttonStyle(.plain)
                .contentShape(Rectangle())
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .sensoryFeedback(.selection, trigger: controller.selectedChoice)
    }
}

private struct TextAnswerInputView: View {
    @Bindable var controller: QuestionInputController
    let onSubmit: () -> Void

    var body: some View {
        TextField("Type your answer in English", text: $controller.textAnswer)
            .textFieldStyle(.roundedBorder)
            .font(.body)
            .autocorrectionDisabled(true)
            .textInputAutocapitalization(.never)
            .submitLabel(.done)
            .onSubmit {
                if controller.canSubmit { onSubmit() }
            }
            .frame(minHeight: 44)
    }
}
