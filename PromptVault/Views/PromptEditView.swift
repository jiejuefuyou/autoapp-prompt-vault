import SwiftUI

struct PromptEditView: View {
    @Environment(IAPManager.self) private var iap
    @Environment(\.dismiss) private var dismiss

    let initial: Prompt?
    let onSave: (Prompt) -> Void
    var onDelete: (() -> Void)? = nil
    var onUse: ((String) -> Void)? = nil

    @State private var title: String
    @State private var promptBody: String
    @State private var tagsText: String
    @State private var variableValues: [String: String] = [:]
    @State private var showPaywall = false
    @State private var showShare = false

    init(initial: Prompt?,
         onSave: @escaping (Prompt) -> Void,
         onDelete: (() -> Void)? = nil,
         onUse: ((String) -> Void)? = nil) {
        self.initial = initial
        self.onSave = onSave
        self.onDelete = onDelete
        self.onUse = onUse
        _title    = State(initialValue: initial?.title ?? "")
        _promptBody = State(initialValue: initial?.body ?? "")
        _tagsText = State(initialValue: (initial?.tags ?? []).joined(separator: ", "))
    }

    private var draft: Prompt {
        Prompt(
            id: initial?.id ?? UUID(),
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            body: promptBody,
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
                Section(LocalizedStringKey("Title")) {
                    TextField(LocalizedStringKey("e.g. Translate to natural English"), text: $title)
                        .submitLabel(.done)
                }
                Section(LocalizedStringKey("Prompt body")) {
                    TextEditor(text: $promptBody)
                        .frame(minHeight: 140)
                        .font(.system(.body, design: .monospaced))
                }
                Section {
                    if iap.hasAnyEntitlement {
                        TextField(LocalizedStringKey("comma,separated,tags"), text: $tagsText)
                    } else {
                        Button {
                            Haptics.light()
                            showPaywall = true
                        } label: {
                            Label(LocalizedStringKey("Upgrade to use tags"), systemImage: "lock.fill")
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text(LocalizedStringKey("Tags"))
                } footer: {
                    if !iap.hasAnyEntitlement {
                        Text(LocalizedStringKey("Tags are a Premium feature."))
                            .foregroundStyle(.secondary)
                    }
                }

                if !draft.parseVariables().isEmpty {
                    Section(LocalizedStringKey("Variables")) {
                        ForEach(draft.parseVariables(), id: \.name) { pv in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(pv.name).font(.caption).foregroundStyle(.secondary)
                                    if pv.defaultValue != nil {
                                        Spacer()
                                        Text(LocalizedStringKey("default")).font(.caption2).foregroundStyle(.tertiary)
                                    }
                                }
                                switch pv.type {
                                case .multiline:
                                    TextEditor(text: variableBinding(for: pv))
                                        .frame(minHeight: 80)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 6)
                                                .stroke(Color.secondary.opacity(0.3), lineWidth: 0.5)
                                        )
                                case .int:
                                    TextField(pv.defaultValue ?? "", text: variableBinding(for: pv))
                                        .keyboardType(.numberPad)
                                        .autocorrectionDisabled()
                                case .string:
                                    TextField(pv.defaultValue ?? "", text: variableBinding(for: pv))
                                        .autocorrectionDisabled()
                                }
                            }
                        }
                    }
                    Section(LocalizedStringKey("Preview")) {
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
                            Label(LocalizedStringKey("Copy & close"), systemImage: "doc.on.doc")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }

                if onDelete != nil {
                    Section {
                        Button(LocalizedStringKey("Delete prompt"), role: .destructive) {
                            onDelete?()
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle(initial == nil ? Text("New prompt") : Text("Edit prompt"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(LocalizedStringKey("Cancel")) { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(LocalizedStringKey("Save"), action: save)
                        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty
                                  || promptBody.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .sheet(isPresented: $showPaywall) { PaywallView() }
            .sheet(isPresented: $showShare) {
                if let p = initial {
                    PromptShareView(prompt: p)
                }
            }
            .toolbar {
                // Share button — only visible when editing an existing prompt
                if initial != nil {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            showShare = true
                        } label: {
                            Image(systemName: "square.and.arrow.up")
                        }
                    }
                }
            }
        }
    }

    private func variableBinding(for pv: PromptVariable) -> Binding<String> {
        Binding(
            get: { variableValues[pv.name] ?? pv.defaultValue ?? "" },
            set: { variableValues[pv.name] = $0 }
        )
    }

    private func save() {
        let candidate = draft
        guard !candidate.title.isEmpty, !candidate.body.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        if !iap.hasAnyEntitlement && candidate.tags.count > PromptStore.freeTagLimit {
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
