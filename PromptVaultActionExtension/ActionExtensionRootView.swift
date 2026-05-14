import SwiftUI

// MARK: - Root View

struct ActionExtensionRootView: View {
    let sharedText: String
    let onComplete: (String) -> Void
    let onCancel: () -> Void

    @State private var prompts: [SharedPromptDTO] = []
    @State private var selectedPrompt: SharedPromptDTO?
    @State private var variableValues: [String: String] = [:]
    @State private var isLoading = true

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("Loading prompts…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let p = selectedPrompt {
                    PromptFillView(prompt: p, sharedText: sharedText, variableValues: $variableValues)
                } else {
                    PromptPickerView(prompts: prompts, onSelect: { selectedPrompt = $0 })
                }
            }
            .navigationTitle("PromptVault")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onCancel()
                    }
                    .frame(minWidth: 60, minHeight: 44)
                    .contentShape(Rectangle())
                }
                if selectedPrompt != nil {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Back") {
                            selectedPrompt = nil
                            variableValues = [:]
                        }
                        .frame(minWidth: 60, minHeight: 44)
                        .contentShape(Rectangle())
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Copy") {
                            guard let prompt = selectedPrompt else { return }
                            let filled = renderPrompt(prompt, values: variableValues)
                            onComplete(filled)
                        }
                        .frame(minWidth: 60, minHeight: 44)
                        .contentShape(Rectangle())
                    }
                }
            }
            .task {
                prompts = await loadFromAppGroup()
                isLoading = false
            }
        }
    }

    // MARK: - App Group Loading

    private func loadFromAppGroup() async -> [SharedPromptDTO] {
        let groupID = AppGroupSyncService.groupID
        guard let url = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: groupID)?
            .appendingPathComponent("prompts.json"),
              let data = try? Data(contentsOf: url),
              let dtos = try? JSONDecoder().decode([SharedPromptDTO].self, from: data)
        else { return [] }
        return dtos
    }

    // MARK: - Prompt Rendering

    /// Simple `{{key}}` substitution. Variable values missing from the dict
    /// are left as-is so the user can see placeholders in the copied text.
    ///
    /// Note: full typed `{{key:type=default}}` parsing is handled by the main
    /// app's `Prompt.parseVariables()`. This scaffold resolves the bare
    /// `{{key}}` form; v1.1.0 will wire the full parser from a shared module.
    private func renderPrompt(_ prompt: SharedPromptDTO, values: [String: String]) -> String {
        var result = prompt.body
        for (key, value) in values where !value.isEmpty {
            result = result.replacingOccurrences(of: "{{\(key)}}", with: value)
        }
        return result
    }
}

// MARK: - Prompt Picker

struct PromptPickerView: View {
    let prompts: [SharedPromptDTO]
    let onSelect: (SharedPromptDTO) -> Void

    @State private var searchText = ""

    private var filtered: [SharedPromptDTO] {
        guard !searchText.isEmpty else { return prompts }
        return prompts.filter {
            $0.title.localizedCaseInsensitiveContains(searchText) ||
            $0.category.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        List {
            ForEach(filtered) { prompt in
                Button {
                    onSelect(prompt)
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(prompt.title)
                            .font(.body)
                            .foregroundStyle(.primary)
                        Text(prompt.body.prefix(80))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .searchable(text: $searchText, prompt: "Search prompts…")
        .listStyle(.plain)
        .overlay {
            if filtered.isEmpty {
                ContentUnavailableView(
                    searchText.isEmpty ? "No prompts synced" : "No results",
                    systemImage: searchText.isEmpty ? "tray" : "magnifyingglass",
                    description: Text(searchText.isEmpty
                        ? "Open PromptVault once to sync your prompts here."
                        : "Try a different search term.")
                )
            }
        }
    }
}

// MARK: - Prompt Fill

/// Variable-fill UI. For v1.1.0 scaffold:
/// Extracts bare `{{key}}` placeholders and pre-fills the first text field
/// with `sharedText`. Full typed `{{key:type=default}}` parsing is deferred
/// to v1.1.0 PromptKit shared module.
struct PromptFillView: View {
    let prompt: SharedPromptDTO
    let sharedText: String
    @Binding var variableValues: [String: String]

    private var extractedKeys: [String] {
        // Naïve extraction of {{key}} patterns (bare name only, no type)
        let pattern = #/\{\{([^:}]+)(?::[^}]*)?\}\}/#
        var seen: [String] = []
        for match in prompt.body.matches(of: pattern) {
            let key = String(match.output.1).trimmingCharacters(in: .whitespaces)
            if !seen.contains(key) { seen.append(key) }
        }
        return seen
    }

    var body: some View {
        Form {
            Section {
                Text(prompt.body)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: {
                Text("Prompt preview")
            }

            Section {
                ForEach(extractedKeys, id: \.self) { key in
                    HStack {
                        Text(key)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(minWidth: 80, alignment: .leading)
                        Divider()
                        TextField(
                            key,
                            text: Binding(
                                get: {
                                    variableValues[key] ?? (key == extractedKeys.first ? sharedText : "")
                                },
                                set: { variableValues[key] = $0 }
                            )
                        )
                        .autocorrectionDisabled()
                    }
                    .frame(minHeight: 44)
                }
            } header: {
                Text("Fill variables")
            } footer: {
                Text("Tap Copy when done. The filled prompt will be copied to your clipboard.")
            }
        }
    }
}

// MARK: - Shared DTO

/// Minimal prompt representation shared between main app and extension via App Group.
/// Must stay in sync with `AppGroupSyncService.SharedPromptDTO` in the main target.
struct SharedPromptDTO: Identifiable, Codable, Hashable {
    let id: String
    let title: String
    let body: String
    let category: String
}
