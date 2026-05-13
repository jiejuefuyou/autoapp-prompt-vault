import XCTest
@testable import PromptVault

// MARK: - PromptEditViewVariableTests
// Verifies that PromptEditView's Variables section wires to parseVariables() correctly.
// These tests run purely on the model layer (no UI host needed).

final class PromptEditViewVariableTests: XCTestCase {

    func testParseVariablesReturnedToUI() {
        let prompt = Prompt(
            id: UUID(),
            title: "Test",
            body: "Hello {{name}}, you are {{age:int=18}} years old. Tell me {{notes:multiline=}}.",
            tags: []
        )
        let vars = prompt.parseVariables()
        XCTAssertEqual(vars.count, 3)
        XCTAssertEqual(vars[0].name, "name")
        XCTAssertEqual(vars[0].type, .string)
        XCTAssertNil(vars[0].defaultValue)
        XCTAssertEqual(vars[1].name, "age")
        XCTAssertEqual(vars[1].type, .int)
        XCTAssertEqual(vars[1].defaultValue, "18")
        XCTAssertEqual(vars[2].name, "notes")
        XCTAssertEqual(vars[2].type, .multiline)
        XCTAssertEqual(vars[2].defaultValue, "")
    }

    func testVariableBindingUsesDefaultValue() {
        // Ensure variableValues[pv.name] falls back to pv.defaultValue when empty.
        let prompt = Prompt(title: "T", body: "{{lang:string=Japanese}}")
        let vars = prompt.parseVariables()
        XCTAssertEqual(vars.count, 1)
        let pv = vars[0]
        XCTAssertEqual(pv.name, "lang")
        XCTAssertEqual(pv.defaultValue, "Japanese")
        // Simulate the binding get: no override -> defaultValue
        var dict: [String: String] = [:]
        let got = dict[pv.name] ?? pv.defaultValue ?? ""
        XCTAssertEqual(got, "Japanese")
        // Simulate override
        dict[pv.name] = "Spanish"
        let overridden = dict[pv.name] ?? pv.defaultValue ?? ""
        XCTAssertEqual(overridden, "Spanish")
    }

    func testNoVariablesProducesEmptySection() {
        let prompt = Prompt(title: "T", body: "No placeholders here.")
        XCTAssertTrue(prompt.parseVariables().isEmpty)
    }

    func testDuplicateVariableDeduplication() {
        let prompt = Prompt(title: "T", body: "{{x}} and {{x:int=5}}")
        // First occurrence wins; second identical name must be skipped.
        let vars = prompt.parseVariables()
        XCTAssertEqual(vars.count, 1)
        XCTAssertEqual(vars[0].name, "x")
        XCTAssertEqual(vars[0].type, .string)  // first occurrence has no type annotation
    }
}
