import Foundation
import SwiftUI
import Observation

// MARK: - Variable System

/// Supported variable types in the `{{name:type=default}}` syntax.
enum VariableType: String, Codable, Hashable, CaseIterable {
    case string
    case int
    case multiline
}

/// A parsed placeholder from a prompt body.
/// Syntax variants:
///   `{{name}}`                 → name, .string, nil
///   `{{name:string=default}}`  → name, .string, "default"
///   `{{count:int=5}}`          → count, .int,    "5"
///   `{{notes:multiline=}}`     → notes, .multiline, ""
struct PromptVariable: Equatable, Hashable {
    let name: String
    let type: VariableType
    let defaultValue: String?
}

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

    /// Parse all `{{name}}` / `{{name:type=default}}` placeholders found in the
    /// prompt body and return them as typed `PromptVariable` instances.
    ///
    /// - Deduplication: first occurrence wins; subsequent identical names ignored.
    /// - Unknown type tokens fall back to `.string`.
    /// - Whitespace around name/type/default is trimmed.
    ///
    /// Examples:
    ///   `{{topic}}`              → PromptVariable(name:"topic", type:.string, defaultValue:nil)
    ///   `{{lang:string=Japanese}}`→ PromptVariable(name:"lang", type:.string, defaultValue:"Japanese")
    ///   `{{count:int=5}}`        → PromptVariable(name:"count", type:.int,    defaultValue:"5")
    ///   `{{notes:multiline=}}`   → PromptVariable(name:"notes", type:.multiline, defaultValue:"")
    func parseVariables() -> [PromptVariable] {
        // Regex captures everything between {{ and }}, non-greedy
        let pattern = #/\{\{\s*([^}]+?)\s*\}\}/#
        var seen: Set<String> = []
        var result: [PromptVariable] = []
        for match in body.matches(of: pattern) {
            let raw = String(match.output.1).trimmingCharacters(in: .whitespaces)
            // Split on first ':' to separate name from "type=default"
            let colonIdx = raw.firstIndex(of: ":")
            let name: String
            let typeAndDefault: String?
            if let idx = colonIdx {
                name = String(raw[raw.startIndex..<idx]).trimmingCharacters(in: .whitespaces)
                typeAndDefault = String(raw[raw.index(after: idx)...]).trimmingCharacters(in: .whitespaces)
            } else {
                name = raw
                typeAndDefault = nil
            }
            guard !name.isEmpty, !seen.contains(name) else { continue }
            seen.insert(name)
            let varType: VariableType
            let defaultVal: String?
            if let td = typeAndDefault {
                // Split on first '=' to separate type from default value
                if let eqIdx = td.firstIndex(of: "=") {
                    let typePart = String(td[td.startIndex..<eqIdx]).trimmingCharacters(in: .whitespaces)
                    let defPart  = String(td[td.index(after: eqIdx)...])
                    varType    = VariableType(rawValue: typePart) ?? .string
                    defaultVal = defPart  // preserve internal whitespace in default
                } else {
                    varType    = VariableType(rawValue: td) ?? .string
                    defaultVal = nil
                }
            } else {
                varType    = .string
                defaultVal = nil
            }
            result.append(PromptVariable(name: name, type: varType, defaultValue: defaultVal))
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
