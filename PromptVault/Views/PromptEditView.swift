import SwiftUI

struct PromptEditView: View {
    @Environment(IAPManager.self) private var iap
    @Environment(\.dismiss) private var dismiss

    let initial: Prompt?
    let onSave: (Prompt) -> Void
    var onDelete: (() -> Void)? = nil
    var onUse: ((String) -> Void)? = nil

    @State private var title: String
    @State private var body: String
    @State private var tagsText: String
    @State private var variableValues: [String: String] = [:]
    @State private var showPaywall = false

    init(initial: Prompt?,
         onSave: @escaping (Prompt) -> Void,
         onDelete: (() -> Void)? = nil,
         onUse: ((String) -> Void)? = nil) {
        self.initial = initial
        self.onSave = onSave
        self.onDelete = onDelete
        self.onUse = onUse
        _title    = State(initialValue: initial?.title ?? "")
        _body     = State(initialValue: initial?.body ?? "")
        _tagsText = State(initialValue: (initial?.tags ?? []).joined(separator: ", "))
    }

    private var draft: Prompt {
        Prompt(
            id: initial?.id ?? UUID(),
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            body: body,
            tags: tagsText.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty },
            useCount: initial?.useCount ?? 0,
            createdAt: initial?.createdAt ?? .now
        )
    }

    private var rendered: String {
        draft.render(with: variableValues)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Title") {
                    TextField("e.g. Translate to natural English", text: $title)
                        .submitLabel(.done)
                }
                Section("Prompt body") {
                    TextEditor(text: $body)
                        .frame(minHeight: 140)
                        .font(.system(.body, design: .monospaced))
                }
                Section {
                    TextField("comma,separated,tags", text: $tagsText)
                } header: {
                    Text("Tags")
                } footer: {
                    if !iap.isPremium && draft.tags.count > PromptStore.freeTagLimit {
                        Text("Free tier limited to \(PromptStore.freeTagLimit) tags per prompt — upgrade to add more.")
                            .foregroundStyle(.secondary)
                    }
                }

                if !draft.variables.isEmpty {
                    Section("Variables") {
                        ForEach(draft.variables, id: \.self) { v in
                            TextField("{{\(v)}}", text: Binding(
                                get: { variableValues[v] ?? "" },
                                set: { variableValues[v] = $0 }
                            ))
                            .autocorrectionDisabled()
                        }
                    }
                    Section("Preview") {
                        Text(rendered)
                            .font(.system(.footnote, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                }

                if onUse != nil {
                    Section {
                        Button {
                            onUse?(rendered)
                            Haptics.success()
                            dismiss()
                        } label: {
                            Label("Copy & close", systemImage: "doc.on.doc")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }

                if onDelete != nil {
                    Section {
                        Button("Delete prompt", role: .destructive) {
                            onDelete?()
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle(initial == nil ? "New prompt" : "Edit prompt")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save", action: save)
                        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty
                                  || body.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .sheet(isPresented: $showPaywall) { PaywallView() }
        }
    }

    private func save() {
        let candidate = draft
        guard !candidate.title.isEmpty, !candidate.body.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        if !iap.isPremium && candidate.tags.count > PromptStore.freeTagLimit {
            // Trim silently — paywall is shown elsewhere; here we don't block save.
            var tagged = candidate
            tagged.tags = Array(candidate.tags.prefix(PromptStore.freeTagLimit))
            onSave(tagged)
        } else {
            onSave(candidate)
        }
        Haptics.medium()
        dismiss()
    }
}
