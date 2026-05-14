import Foundation

/// Writes a snapshot of the user's prompts to the shared App Group container
/// so the Action Extension can load them without accessing the main app's
/// Documents directory (which is sandboxed and inaccessible cross-process).
///
/// Call `AppGroupSyncService.writePromptsToGroup(_:)` from `PromptStore.save()`
/// whenever the prompt list changes.
enum AppGroupSyncService {

    static let groupID = "group.com.jiejuefuyou.promptvault"

    /// Shared DTO — mirrors `SharedPromptDTO` in the Action Extension target.
    /// Keep both in sync if fields change.
    struct SharedPromptDTO: Codable {
        let id: String
        let title: String
        let body: String
        let category: String
    }

    // MARK: - Write

    /// Serialises `prompts` to `group.com.jiejuefuyou.promptvault/prompts.json`.
    /// Silently no-ops if the App Group container is unavailable (simulator or
    /// missing capability) so it never crashes the main app on capability-related
    /// provisioning issues during CI builds.
    static func writePromptsToGroup(_ prompts: [Prompt]) {
        guard let containerURL = groupContainerURL else { return }
        let url = containerURL.appendingPathComponent("prompts.json")
        let dtos = prompts.map { prompt in
            SharedPromptDTO(
                id: prompt.id.uuidString,
                title: prompt.title,
                body: prompt.body,
                category: prompt.category ?? "general"
            )
        }
        guard let data = try? JSONEncoder().encode(dtos) else { return }
        try? data.write(to: url, options: .atomic)
    }

    // MARK: - Private

    private static var groupContainerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: groupID)
    }
}
