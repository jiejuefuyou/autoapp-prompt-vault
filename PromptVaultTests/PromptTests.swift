import XCTest
@testable import PromptVault

final class PromptTests: XCTestCase {

    func testPromptCodableRoundTrip() throws {
        let original = Prompt(title: "Translate", body: "Translate {{text}}", tags: ["翻译", "Translation"])
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Prompt.self, from: data)
        XCTAssertEqual(decoded.title, original.title)
        XCTAssertEqual(decoded.body, original.body)
        XCTAssertEqual(decoded.tags, original.tags)
    }

    func testPromptDecodesOldSchemaWithoutDefaultedFields() throws {
        // Backward-compat guard: a v1.0.0-era JSON with no tags / useCount /
        // createdAt should still decode and fall back to defaults. See Codable
        // migration audit 2026-05-07 + dev.to article #72.
        let json = #"""
        {
            "id":"00000000-0000-0000-0000-000000000001",
            "title":"Old prompt",
            "body":"Hello world"
        }
        """#.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(Prompt.self, from: json)
        XCTAssertEqual(decoded.title, "Old prompt")
        XCTAssertEqual(decoded.tags, [])
        XCTAssertEqual(decoded.useCount, 0)
    }

    func testVariableExtraction() {
        let p = Prompt(title: "x", body: "Hello {{name}}, welcome to {{place}}. Again, {{name}}.")
        XCTAssertEqual(p.variables, ["name", "place"])
    }

    func testRenderSubstitution() {
        let p = Prompt(title: "x", body: "Hi {{name}}, {{ greeting }}!")
        let out = p.render(with: ["name": "Anna", "greeting": "good day"])
        XCTAssertEqual(out, "Hi Anna, good day!")
    }

    func testRenderLeavesUnresolvedVariables() {
        let p = Prompt(title: "x", body: "Hi {{name}}, age {{age}}")
        let out = p.render(with: ["name": "Anna"])
        XCTAssertEqual(out, "Hi Anna, age {{age}}")
    }

    func testStoreCRUD() {
        let store = PromptStore()
        let initialCount = store.prompts.count

        let p = Prompt(title: "Test", body: "Body {{x}}", tags: ["test"])
        store.add(p)
        XCTAssertEqual(store.prompts.count, initialCount + 1)

        var updated = p
        updated.title = "Updated"
        store.update(updated)
        XCTAssertEqual(store.prompts.first(where: { $0.id == p.id })?.title, "Updated")

        store.delete(p)
        XCTAssertEqual(store.prompts.count, initialCount)
    }

    func testRecordUsedIncrementsCount() {
        let store = PromptStore()
        let p = Prompt(title: "T", body: "B")
        store.add(p)
        let before = store.prompts.first(where: { $0.id == p.id })?.useCount ?? 0
        store.recordUsed(p)
        let after = store.prompts.first(where: { $0.id == p.id })?.useCount ?? 0
        XCTAssertEqual(after, before + 1)
        store.delete(p)
    }

    func testFreePromptLimitConstant() {
        XCTAssertGreaterThanOrEqual(PromptStore.freePromptLimit, 5)
        XCTAssertLessThanOrEqual(PromptStore.freePromptLimit, 50)
    }

    func testSortByUseCountThenRecency() {
        let store = PromptStore()
        for p in store.prompts { store.delete(p) }

        var a = Prompt(title: "a", body: "x"); a.useCount = 0
        var b = Prompt(title: "b", body: "x"); b.useCount = 5
        var c = Prompt(title: "c", body: "x"); c.useCount = 5
        c.createdAt = Date(timeIntervalSinceNow: 100)  // newer
        store.add(a); store.add(b); store.add(c)

        let sorted = store.sortedPrompts
        XCTAssertEqual(sorted.first?.title, "c", "most recent of tied use-count should be first")
        XCTAssertEqual(sorted.last?.title, "a", "lowest use-count goes last")
    }

    func testStarterPackLoadsFromBundle() {
        // The bundled JSON should have at least 20 entries.
        let pack = StarterPack.load()
        XCTAssertGreaterThanOrEqual(pack.count, 20, "starter_prompts.json should ship 20+ prompts")
    }

    func testMergeFromiCloudOverwritesLocal() {
        // v1.0.1 — iCloud merge replaces local state when the remote payload differs.
        let store = PromptStore()
        for p in store.prompts { store.delete(p) }

        let local = Prompt(title: "Local", body: "L")
        store.add(local)

        let remote = Prompt(title: "Remote", body: "R")
        store.mergeFromiCloud([remote])

        XCTAssertEqual(store.prompts.count, 1, "remote payload should overwrite local")
        XCTAssertEqual(store.prompts.first?.title, "Remote")
    }

    func testMergeFromiCloudNoopWhenIdentical() {
        // v1.0.1 — guard against the bounce-back loop: merging the same array
        // we just pushed must not retrigger save() and notifications.
        let store = PromptStore()
        for p in store.prompts { store.delete(p) }
        let p = Prompt(title: "Same", body: "S")
        store.add(p)
        let snapshot = store.prompts
        store.mergeFromiCloud(snapshot)
        XCTAssertEqual(store.prompts, snapshot)
    }
}
