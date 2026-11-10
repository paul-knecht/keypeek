import XCTest
@testable import KeyPeek

// Checks the request we send to Claude and how we read its answer.
// None of these tests uses the network or an API key.
final class RankingClientTests: XCTestCase {

    private let shortcuts = [
        Shortcut(menuPath: ["File"], title: "New Window", keys: "⌘N"),
        Shortcut(menuPath: ["File"], title: "Close", keys: "⌘W"),
        Shortcut(menuPath: ["Edit"], title: "Copy", keys: "⌘C"),
    ]

    // Builds a fake API answer like the real one: some blocks, one of them text holding JSON.
    private func response(top: [Int], extra: [[String: String]] = [], stopReason: String = "end_turn") -> Data {
        let answer = try! JSONSerialization.data(withJSONObject: ["top": top, "extra": extra])
        let body: [String: Any] = [
            "stop_reason": stopReason,
            "content": [
                ["type": "thinking", "thinking": ""],
                ["type": "text", "text": String(data: answer, encoding: .utf8)!],
            ],
        ]
        return try! JSONSerialization.data(withJSONObject: body)
    }

    // Reads the request body back so tests can look inside it.
    private func decodedBody(_ shortcuts: [Shortcut]) throws -> (json: [String: Any], text: String) {
        let data = try RankingClient.requestBody(appName: "Finder", shortcuts: shortcuts)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let messages = try XCTUnwrap(json["messages"] as? [[String: Any]])
        let text = try XCTUnwrap(messages.first?["content"] as? String)
        return (json, text)
    }

    func testRequestBodyHasModelAndSchema() throws {
        let body = try decodedBody(shortcuts)
        XCTAssertEqual(body.json["model"] as? String, "claude-sonnet-5-5")
        let config = try XCTUnwrap(body.json["output_config"] as? [String: Any])
        let format = try XCTUnwrap(config["format"] as? [String: Any])
        XCTAssertEqual(format["type"] as? String, "json_schema")
        XCTAssertNotNil(format["schema"])
        XCTAssertTrue(body.text.contains("0. File > New Window — ⌘N"))
        XCTAssertTrue(body.text.contains("Finder"))
    }

    func testRequestBodyHasNoRejectedFields() throws {
        let body = try decodedBody(shortcuts)
        XCTAssertNil(body.json["thinking"])
        XCTAssertNil(body.json["temperature"])
        XCTAssertNil(body.json["tool_choice"])
    }

    func testRequestBodyCapsAt400() throws {
        let many = (0..<450).map { Shortcut(menuPath: ["Menu"], title: "Item \($0)", keys: "⌘A") }
        let body = try decodedBody(many)
        XCTAssertTrue(body.text.contains("399. "))
        XCTAssertFalse(body.text.contains("400. "))
    }

    func testParseValid() throws {
        let data = response(top: [2, 0], extra: [["keys": "⇧⌘.", "description": "Show hidden files"]])
        let result = try RankingClient.parse(data, statusCode: 200, shortcuts: shortcuts)
        XCTAssertEqual(result.topIDs, ["Edit > Copy", "File > New Window"])
        XCTAssertEqual(result.suggestions, [Suggestion(keys: "⇧⌘.", description: "Show hidden files")])
    }

    func testParseDropsBadIndices() throws {
        let data = response(top: [0, 0, 99, -1, 1])
        let result = try RankingClient.parse(data, statusCode: 200, shortcuts: shortcuts)
        XCTAssertEqual(result.topIDs, ["File > New Window", "File > Close"])
    }

    func testParseCapsAtTenAndEight() throws {
        let many = (0..<20).map { Shortcut(menuPath: ["Menu"], title: "Item \($0)", keys: "⌘\($0)") }
        let extra = (0..<12).map { ["keys": "⌃F\($0)", "description": "Extra \($0)"] }
        let data = response(top: Array(0..<20), extra: extra)
        let result = try RankingClient.parse(data, statusCode: 200, shortcuts: many)
        XCTAssertEqual(result.topIDs.count, 10)
        XCTAssertEqual(result.suggestions.count, 8)
    }

    func testParseDropsSuggestionDuplicatingMenuKeys() throws {
        let extra = [
            ["keys": "⌘N", "description": "Already in the menus"],
            ["keys": "⌘ n", "description": "Same keys written differently"],
            ["keys": "⇧⌘.", "description": "Show hidden files"],
        ]
        let result = try RankingClient.parse(response(top: [], extra: extra), statusCode: 200, shortcuts: shortcuts)
        XCTAssertEqual(result.suggestions.map(\.keys), ["⇧⌘."])
    }

    func testParseDropsSuggestionWithModifiersInAnotherOrder() throws {
        let menu = [Shortcut(menuPath: ["View"], title: "Show Hidden Files", keys: "⇧⌘.")]
        let extra = [["keys": "⌘⇧.", "description": "Same keys, modifiers swapped"]]
        let result = try RankingClient.parse(response(top: [], extra: extra), statusCode: 200, shortcuts: menu)
        XCTAssertEqual(result.suggestions, [])
    }

    func testParseDropsRepeatedSuggestions() throws {
        let extra = [
            ["keys": "⇧⌘.", "description": "Show hidden files"],
            ["keys": "⌘⇧.", "description": "Toggle hidden files"],
            ["keys": "⌥⌘P", "description": "Show path bar"],
        ]
        let result = try RankingClient.parse(response(top: [], extra: extra), statusCode: 200, shortcuts: shortcuts)
        XCTAssertEqual(result.suggestions.map(\.description), ["Show hidden files", "Show path bar"])
    }

    func testParseDropsEmptySuggestions() throws {
        let extra = [["keys": "", "description": "No keys"], ["keys": "⌘J", "description": " "]]
        let result = try RankingClient.parse(response(top: [], extra: extra), statusCode: 200, shortcuts: shortcuts)
        XCTAssertEqual(result.suggestions, [])
    }

    private func assertParse(_ data: Data, status: Int, throws expected: RankingError,
                             file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertThrowsError(try RankingClient.parse(data, statusCode: status, shortcuts: shortcuts),
                             file: file, line: line) { error in
            XCTAssertEqual(error as? RankingError, expected, file: file, line: line)
        }
    }

    func testParse401() {
        assertParse(Data("{}".utf8), status: 401, throws: .unauthorized)
    }

    func testParse500() {
        assertParse(Data("{}".utf8), status: 500, throws: .failed)
    }

    func testParseRefusal() {
        assertParse(response(top: [], stopReason: "refusal"), status: 200, throws: .refused)
    }

    func testParseMaxTokens() {
        assertParse(response(top: [0], stopReason: "max_tokens"), status: 200, throws: .failed)
    }

    func testParseGarbage() {
        assertParse(Data("not json".utf8), status: 200, throws: .failed)
    }

    func testRankWithoutKey() async {
        for key in [nil, "", "   "] as [String?] {
            do {
                _ = try await RankingClient.rank(appName: "Finder", shortcuts: shortcuts, apiKey: key)
                XCTFail("Expected an error")
            } catch {
                XCTAssertEqual(error as? RankingError, .noKey)
            }
        }
    }
}
