import Foundation

/// Bundled starter prompts loaded from Resources/starter_prompts.json on first launch.
/// Free tier sees the first `freePromptLimit` items; premium users get the full list.
enum StarterPack {
    static func load() -> [Prompt] {
        guard let url = Bundle.main.url(forResource: "starter_prompts", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let raw = try? JSONDecoder().decode([RawPrompt].self, from: data)
        else {
            return fallback
        }
        return raw.map(\.prompt)
    }

    /// In-binary fallback in case the JSON resource fails to load. Keeps app usable.
    /// Starter pack prompts are marked `isStarter: true` so they don't count
    /// against the free-tier `freePromptLimit` (v1.1.2 fix: prevent overflow on
    /// first launch where 150 starter prompts blocked user from saving any).
    private static let fallback: [Prompt] = [
        Prompt(title: "Translate to natural English",
               body: "Translate the following text into natural, conversational English. Preserve the tone and any technical terms.\n\n{{text}}",
               tags: ["翻译", "Translation"],
               isStarter: true),
        Prompt(title: "Summarize a long article",
               body: "Summarize the following article in 5 bullet points, then 1 takeaway sentence.\n\n{{article}}",
               tags: ["总结", "Summarize"],
               isStarter: true),
    ]

    private struct RawPrompt: Codable {
        let id: String?
        let title: String
        let body: String
        let tags: [String]?
        let category: String?   // v1.1.0: 5-bucket categorisation

        var prompt: Prompt {
            Prompt(title: title, body: body, tags: tags ?? [], category: category, isStarter: true)
        }
    }
}
