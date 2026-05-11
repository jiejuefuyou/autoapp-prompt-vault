import SwiftUI

/// First-launch quick tour. Onboarding gets the user to "I get it" in ~30 seconds
/// by walking through one real starter prompt: pick → fill variable → copy.
/// Apple's utility-app data: Day-0 onboarding is 86% of trial-to-paid decisions.
struct QuickTourView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("hasCompletedTour") private var hasCompletedTour: Bool = false

    @State private var stepIndex: Int = 0
    @State private var variableValue: String = ""
    @State private var didCopy: Bool = false

    /// A pre-picked example prompt for the tour. Use a translation prompt — it has
    /// universal appeal and lets the user see {{variable}} substitution work.
    private let example = Prompt(
        title: "Translate to natural English",
        body: "Translate the following text into natural, conversational English. Preserve technical terms.\n\n{{text}}",
        tags: ["翻译", "Translation"]
    )

    private var rendered: String {
        example.render(with: ["text": variableValue.isEmpty ? "[your text here]" : variableValue])
    }

    private let stepKeys: [LocalizedStringKey] = [
        "Pick a saved prompt",
        "Fill in the {{variable}}",
        "One tap to copy",
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Progress
            HStack(spacing: 8) {
                ForEach(0..<stepKeys.count, id: \.self) { i in
                    Capsule()
                        .fill(i <= stepIndex ? Color.accentColor : Color(.tertiarySystemFill))
                        .frame(height: 4)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 12)

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text(stepKeys[stepIndex])
                        .font(.title2.bold())
                        .padding(.top, 16)

                    if stepIndex == 0 {
                        step1Picker
                    } else if stepIndex == 1 {
                        step2Variable
                    } else {
                        step3Copy
                    }
                }
                .padding(.horizontal, 24)
            }

            Spacer()

            actionButton
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
        }
        .navigationBarBackButtonHidden(true)
        .interactiveDismissDisabled(true)
    }

    @ViewBuilder
    private var step1Picker: some View {
        Text(LocalizedStringKey("Your library comes with 100+ ready-to-use prompts for ChatGPT / Claude / Midjourney / Coze. Tap any of them to use."))
            .foregroundStyle(.secondary)

        VStack(alignment: .leading, spacing: 8) {
            Text(example.title)
                .font(.headline)
            Text(example.body)
                .font(.system(.footnote, design: .monospaced))
                .foregroundStyle(.secondary)
                .lineLimit(4)
            HStack {
                ForEach(example.tags, id: \.self) { t in
                    Text(t)
                        .font(.caption2)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.accentColor.opacity(0.12), in: Capsule())
                        .foregroundStyle(Color.accentColor)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
    }

    @ViewBuilder
    private var step2Variable: some View {
        Text(LocalizedStringKey("This prompt has a `{{text}}` placeholder. Type or paste anything and watch the prompt fill in."))
            .foregroundStyle(.secondary)

        VStack(alignment: .leading, spacing: 8) {
            Text("{{text}}")
                .font(.system(.subheadline, design: .monospaced))
                .foregroundStyle(.secondary)
            TextField(LocalizedStringKey("e.g. 这家餐厅味道不错但服务很慢"), text: $variableValue, axis: .vertical)
                .lineLimit(3, reservesSpace: true)
                .padding(10)
                .background(Color(.tertiarySystemBackground), in: RoundedRectangle(cornerRadius: 8))
        }

        Text(LocalizedStringKey("Live preview"))
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.top, 8)
        Text(rendered)
            .font(.system(.footnote, design: .monospaced))
            .foregroundStyle(.primary)
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 8))
    }

    @ViewBuilder
    private var step3Copy: some View {
        Text(LocalizedStringKey("In the real app, swipe right on any row to copy. Try it now."))
            .foregroundStyle(.secondary)

        Button {
            UIPasteboard.general.string = rendered
            Haptics.success()
            withAnimation { didCopy = true }
        } label: {
            HStack {
                Image(systemName: didCopy ? "checkmark.circle.fill" : "doc.on.doc")
                Text(didCopy ? LocalizedStringKey("Copied to clipboard") : LocalizedStringKey("Tap to copy"))
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(didCopy ? Color.green : Color.accentColor, in: RoundedRectangle(cornerRadius: 14))
            .foregroundStyle(.white)
        }
        .padding(.top, 8)

        if didCopy {
            Text(LocalizedStringKey("Now paste it into ChatGPT / Claude / your tool of choice. That's the whole loop."))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.top, 12)
                .transition(.opacity)
        }
    }

    @ViewBuilder
    private var actionButton: some View {
        if stepIndex < stepKeys.count - 1 {
            Button {
                Haptics.light()
                withAnimation { stepIndex += 1 }
            } label: {
                Text(LocalizedStringKey("Next"))
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 14))
                    .foregroundStyle(.white)
            }
            .buttonStyle(ScaleButtonStyle())
        } else {
            Button {
                hasCompletedTour = true
                dismiss()
            } label: {
                Text(didCopy ? LocalizedStringKey("Get started") : LocalizedStringKey("Skip"))
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(didCopy ? Color.accentColor : Color(.systemGray4),
                                in: RoundedRectangle(cornerRadius: 14))
                    .foregroundStyle(didCopy ? .white : .primary)
            }
            .buttonStyle(ScaleButtonStyle())
        }
    }
}

#Preview {
    QuickTourView()
}
