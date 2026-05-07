import SwiftUI

struct ContentView: View {
    @Environment(PromptStore.self) private var store
    @Environment(IAPManager.self) private var iap

    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding: Bool = false
    @AppStorage("hasCompletedTour") private var hasCompletedTour: Bool = false

    @State private var showSettings = false
    @State private var showPaywall = false
    @State private var editingPrompt: Prompt?
    @State private var addingPrompt = false
    @State private var search = ""
    @State private var showScanner = false

    private var visiblePrompts: [Prompt] {
        let pool = store.filteredPrompts
        guard !search.isEmpty else { return pool }
        let q = search.lowercased()
        return pool.filter {
            $0.title.lowercased().contains(q)
            || $0.body.lowercased().contains(q)
            || $0.tags.contains { $0.lowercased().contains(q) }
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if store.prompts.isEmpty {
                    ContentUnavailableView {
                        Label("No prompts yet", systemImage: "sparkles")
                    } description: {
                        Text("Tap + to save your first prompt.")
                    }
                } else {
                    List {
                        if !store.allTags.isEmpty {
                            tagFilterRow
                                .listRowInsets(EdgeInsets())
                                .listRowBackground(Color.clear)
                        }
                        ForEach(visiblePrompts) { p in
                            PromptRow(prompt: p)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    Haptics.light()
                                    editingPrompt = p
                                }
                                .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                    Button {
                                        copy(p)
                                    } label: {
                                        Label("Copy", systemImage: "doc.on.doc")
                                    }.tint(.accentColor)
                                }
                        }
                        .onDelete(perform: deleteAt)
                    }
                    .listStyle(.insetGrouped)
                    .searchable(text: $search, placement: .navigationBarDrawer(displayMode: .always),
                                prompt: "Search prompts")
                }
            }
            .navigationTitle("PromptVault")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { showSettings = true } label: { Image(systemName: "gear") }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 4) {
                        Button {
                            Haptics.light()
                            showScanner = true
                        } label: { Image(systemName: "qrcode.viewfinder") }

                        Button {
                            Haptics.light()
                            if !iap.isPremium && store.prompts.count >= PromptStore.freePromptLimit {
                                showPaywall = true
                            } else {
                                addingPrompt = true
                            }
                        } label: { Image(systemName: "plus") }
                    }
                }
            }
            .sheet(isPresented: $showSettings) { SettingsView() }
            .sheet(isPresented: $showPaywall) { PaywallView() }
            .sheet(isPresented: $addingPrompt) {
                PromptEditView(initial: nil) { newPrompt in
                    store.add(newPrompt)
                    Haptics.success()
                }
            }
            .sheet(isPresented: $showScanner) {
                PromptScanView()
            }
            .sheet(item: $editingPrompt) { p in
                PromptEditView(initial: p,
                               onSave: { updated in store.update(updated) },
                               onDelete: { store.delete(p); Haptics.warning() },
                               onUse: { rendered in copy(p, body: rendered) })
            }
            .fullScreenCover(isPresented: Binding(
                get: { !hasSeenOnboarding },
                set: { _ in /* OnboardingView writes hasSeenOnboarding directly */ }
            )) {
                OnboardingView(hasSeenOnboarding: $hasSeenOnboarding)
            }
            // Show the quick tour after onboarding finishes, only once.
            .sheet(isPresented: Binding(
                get: { hasSeenOnboarding && !hasCompletedTour },
                set: { _ in /* QuickTourView writes hasCompletedTour directly */ }
            )) {
                QuickTourView()
            }
        }
    }

    @ViewBuilder
    private var tagFilterRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                pill(label: "All", selected: store.activeTagFilter == nil) {
                    store.activeTagFilter = nil
                }
                ForEach(store.allTags, id: \.self) { tag in
                    pill(label: tag, selected: store.activeTagFilter == tag) {
                        store.activeTagFilter =
                            (store.activeTagFilter == tag) ? nil : tag
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }

    private func pill(label: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: { Haptics.light(); action() }) {
            Text(label)
                .font(.subheadline)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(selected ? Color.accentColor : Color(.secondarySystemFill),
                            in: Capsule())
                .foregroundStyle(selected ? .white : .primary)
        }
    }

    private func copy(_ prompt: Prompt, body: String? = nil) {
        let text = body ?? prompt.body
        UIPasteboard.general.string = text
        Haptics.success()
        store.recordUsed(prompt)
    }

    private func deleteAt(_ offsets: IndexSet) {
        for i in offsets {
            if let p = visiblePrompts[safe: i] { store.delete(p) }
        }
    }
}

private struct PromptRow: View {
    let prompt: Prompt

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(prompt.title)
                    .font(.headline)
                    .lineLimit(1)
                Spacer()
                if prompt.useCount > 0 {
                    Text("\(prompt.useCount)×")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
            Text(prompt.body)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
            if !prompt.tags.isEmpty {
                HStack(spacing: 6) {
                    ForEach(prompt.tags.prefix(3), id: \.self) { t in
                        Text(t)
                            .font(.caption2)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.accentColor.opacity(0.12), in: Capsule())
                            .foregroundStyle(Color.accentColor)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

#Preview {
    ContentView()
        .environment(PromptStore())
        .environment(IAPManager())
}
