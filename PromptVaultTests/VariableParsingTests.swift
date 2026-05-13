import XCTest
@testable import PromptVault

// MARK: - VariableParsingTests
// Tests for the {{name:type=default}} variable system introduced in v1.0.3.

final class VariableParsingTests: XCTestCase {

    // MARK: Basic cases

    func testParseSimpleVariable() {
        // {{name}} → .string, no default
        let p = Prompt(title: "t", body: "Hello {{name}}")
        let vars = p.parseVariables()
        XCTAssertEqual(vars.count, 1)
        XCTAssertEqual(vars[0].name, "name")
        XCTAssertEqual(vars[0].type, .string)
        XCTAssertNil(vars[0].defaultValue)
    }

    func testParseTypedDefault() {
        // {{topic:string=AI}} → .string, default "AI"
        let p = Prompt(title: "t", body: "Write about {{topic:string=AI}}")
        let vars = p.parseVariables()
        XCTAssertEqual(vars.count, 1)
        XCTAssertEqual(vars[0].name, "topic")
        XCTAssertEqual(vars[0].type, .string)
        XCTAssertEqual(vars[0].defaultValue, "AI")
    }

    func testParseInt() {
        // {{count:int=5}} → .int, default "5"
        let p = Prompt(title: "t", body: "Generate {{count:int=5}} examples of {{concept}}")
        let vars = p.parseVariables()
        XCTAssertEqual(vars.count, 2)
        let countVar = vars[0]
        XCTAssertEqual(countVar.name, "count")
        XCTAssertEqual(countVar.type, .int)
        XCTAssertEqual(countVar.defaultValue, "5")
        // second var: simple string
        XCTAssertEqual(vars[1].name, "concept")
        XCTAssertEqual(vars[1].type, .string)
        XCTAssertNil(vars[1].defaultValue)
    }

    func testParseMultiline() {
        // {{notes:multiline=}} → .multiline, default ""
        let p = Prompt(title: "t", body: "Context:\n{{notes:multiline=}}\nAnswer:")
        let vars = p.parseVariables()
        XCTAssertEqual(vars.count, 1)
        XCTAssertEqual(vars[0].name, "notes")
        XCTAssertEqual(vars[0].type, .multiline)
        XCTAssertEqual(vars[0].defaultValue, "")
    }

    // MARK: Edge cases

    func testDeduplicationKeepsFirstOccurrence() {
        // Same name appearing twice → single entry
        let p = Prompt(title: "t", body: "{{lang:string=French}} and {{lang:string=German}}")
        let vars = p.parseVariables()
        XCTAssertEqual(vars.count, 1)
        XCTAssertEqual(vars[0].defaultValue, "French", "first occurrence wins")
    }

    func testUnknownTypeFallsBackToString() {
        // {{x:url=}} → unknown type "url" → falls back to .string
        let p = Prompt(title: "t", body: "Visit {{x:url=https://example.com}}")
        let vars = p.parseVariables()
        XCTAssertEqual(vars.count, 1)
        XCTAssertEqual(vars[0].type, .string)
        XCTAssertEqual(vars[0].defaultValue, "https://example.com")
    }

    func testWhitespaceTrimmedAroundName() {
        // {{  name  }} should parse to name "name"
        let p = Prompt(title: "t", body: "Hello {{  name  }}")
        let vars = p.parseVariables()
        XCTAssertEqual(vars.count, 1)
        XCTAssertEqual(vars[0].name, "name")
    }

    func testMultipleVariablesOrdered() {
        // Variables returned in order of first appearance
        let body = "{{a}} then {{b:int=10}} then {{c:multiline=}} then {{a}} again"
        let p = Prompt(title: "t", body: body)
        let vars = p.parseVariables()
        XCTAssertEqual(vars.map(\.name), ["a", "b", "c"])
    }

    func testEmptyBodyReturnsNoVariables() {
        let p = Prompt(title: "t", body: "No placeholders here.")
        XCTAssertEqual(p.parseVariables(), [])
    }

    func testDefaultValueWithSpacesPreserved() {
        // Default value internal whitespace must survive
        let p = Prompt(title: "t", body: "{{greeting:string=Hello World}}")
        let vars = p.parseVariables()
        XCTAssertEqual(vars[0].defaultValue, "Hello World")
    }

    func testTypeOnlyWithoutDefault() {
        // {{name:string}} — type provided but no '=' → nil default
        let p = Prompt(title: "t", body: "{{name:string}}")
        let vars = p.parseVariables()
        XCTAssertEqual(vars.count, 1)
        XCTAssertEqual(vars[0].type, .string)
        XCTAssertNil(vars[0].defaultValue)
    }

    // MARK: Backward-compat: existing `variables` property still works

    func testLegacyVariablesPropertyUnchanged() {
        // Existing `variables: [String]` must still extract bare names
        let p = Prompt(title: "t", body: "{{foo}} and {{bar:int=3}}")
        // legacy property uses simpler regex that captures full raw token
        // so "bar:int=3" will be in legacy — that's fine; parseVariables() is the canonical new API
        XCTAssertTrue(p.variables.contains("foo"))
    }
}
