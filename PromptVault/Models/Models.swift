import Foundation
import SwiftUI
import Observation

struct Prompt: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var title: String
    var body: String
    var tags: [String] = []
    var useCount: Int = 0
    var createdAt: Date = .now

    /// All `{{var}}` placeholders found in the body, deduped, in order of first appearance.
    var variables: [String] {
        let pattern = #/\{\{\s*([^}]+?)\s*\}\}/#
        var seen: [String] = []
        for match in body.matches(of: pattern) {
            let name = String(match.output.1)
            if !seen.contains(name) { seen.append(name) }
        }
        return seen
    }

    /// Substitute `{{var}}` placeholders. Missing keys are left as-is.
    func render(with values: [String: String]) -> String {
        var result = body
        for (key, val) in values {
            result = result.replacingOccurrences(of: "{{\(key)}}", with: val)
            result = result.replacingOccurrences(of: "{{ \(key) }}", with: val)
        }
        return result
    }
}

@Observable
final class PromptStore {
    static let freePromptLimit = 10
    static let freeTagLimit = 3

    var prompts: [Prompt] = []
    /// User's pinned/recent tags for filtering UI.
    var activeTagFilter: String? = nil

    init() {
        load()
        if ProcessInfo.processInfo.arguments.contains("-FASTLANE_SNAPSHOT") {
            seedForSnapshot()
        } else if prompts.isEmpty {
            // First launch: load the bundled starter pack.
            prompts = StarterPack.load()
            save()
        }
    }

    var allTags: [String] {
        var seen = Set<String>()
        var out: [String] = []
        for p in prompts {
            for t in p.tags where !seen.contains(t) {
                seen.insert(t)
                out.append(t)
            }
        }
        return out.sorted()
    }

    var filteredPrompts: [Prompt] {
        guard let tag = activeTagFilter else { return sortedPrompts }
        return sortedPrompts.filter { $0.tags.contains(tag) }
    }

    /// Most-used first; ties broken by most-recently-created.
    var sortedPrompts: [Prompt] {
        prompts.sorted { lhs, rhs in
            if lhs.useCount != rhs.useCount { return lhs.useCount > rhs.useCount }
            return lhs.createdAt > rhs.createdAt
        }
    }

    func add(_ p: Prompt) {
        prompts.append(p)
        save()
        Task { @MainActor in
            ReviewService.recordSuccess()
            ReviewService.maybeRequestReview()
        }
    }

    func update(_ p: Prompt) {
        guard let idx = prompts.firstIndex(where: { $0.id == p.id }) else { return }
        prompts[idx] = p
        save()
    }

    func delete(_ p: Prompt) {
        prompts.removeAll { $0.id == p.id }
        save()
    }

    func recordUsed(_ p: Prompt) {
        guard let idx = prompts.firstIndex(where: { $0.id == p.id }) else { return }
        prompts[idx].useCount += 1
        save()
        Task { @MainActor in
            ReviewService.recordSuccess()
            ReviewService.maybeRequestReview()
        }
    }

    private func seedForSnapshot() {
        // Five realistic prompts for screenshots. Don't save() — keep prod sandbox clean.
        prompts = StarterPack.load().prefix(5).map { $0 }
    }

    // MARK: - Persistence

    private var saveURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            .appendingPathComponent("promptvault_state.json")
    }

    private func save() {
        if let data = try? JSONEncoder().encode(prompts) {
            try? data.write(to: saveURL, options: .atomic)
        }
    }

    private func load() {
        guard let data = try? Data(contentsOf: saveURL),
              let arr = try? JSONDecoder().decode([Prompt].self, from: data) else { return }
        prompts = arr
    }
}
