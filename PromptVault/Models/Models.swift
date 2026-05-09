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

    init(id: UUID = UUID(),
         title: String,
         body: String,
         tags: [String] = [],
         useCount: Int = 0,
         createdAt: Date = .now) {
        self.id = id
        self.title = title
        self.body = body
        self.tags = tags
        self.useCount = useCount
        self.createdAt = createdAt
    }

    enum CodingKeys: String, CodingKey {
        case id, title, body, tags, useCount, createdAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id        = try c.decodeIfPresent(UUID.self,     forKey: .id) ?? UUID()
        self.title     = try c.decode(String.self,            forKey: .title)
        self.body      = try c.decode(String.self,            forKey: .body)
        self.tags      = try c.decodeIfPresent([String].self, forKey: .tags) ?? []
        self.useCount  = try c.decodeIfPresent(Int.self,      forKey: .useCount) ?? 0
        self.createdAt = try c.decodeIfPresent(Date.self,     forKey: .createdAt) ?? .now
    }

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

    private var icloudSync: iCloudSyncManager?

    func attachiCloudSync(_ sync: iCloudSyncManager?) {
        icloudSync = sync
    }

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
        pushiCloud()
        Task { @MainActor in
            ReviewService.recordSuccess()
            ReviewService.maybeRequestReview()
        }
    }

    func update(_ p: Prompt) {
        guard let idx = prompts.firstIndex(where: { $0.id == p.id }) else { return }
        prompts[idx] = p
        save()
        pushiCloud()
    }

    func delete(_ p: Prompt) {
        prompts.removeAll { $0.id == p.id }
        save()
        pushiCloud()
    }

    func recordUsed(_ p: Prompt) {
        guard let idx = prompts.firstIndex(where: { $0.id == p.id }) else { return }
        prompts[idx].useCount += 1
        save()
        pushiCloud()
        Task { @MainActor in
            ReviewService.recordSuccess()
            ReviewService.maybeRequestReview()
        }
    }

    /// Hop to the main actor and push the latest snapshot to iCloud, if attached.
    /// The closure captures `self` weakly so a deallocated store doesn't pin the manager.
    private func pushiCloud() {
        let snapshot = prompts
        Task { @MainActor [weak self] in
            self?.icloudSync?.push(snapshot)
        }
    }

    /// Called by iCloudSyncManager when remote changes arrive.
    /// Replaces local state with the remote payload only if it strictly differs;
    /// otherwise no-ops so we don't churn the UI / file write loop.
    func mergeFromiCloud(_ remote: [Prompt]) {
        guard remote != prompts else { return }
        prompts = remote
        save()
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
