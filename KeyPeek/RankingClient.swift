import Foundation

// What Claude answered for one app.
struct RankingResult: Equatable, Codable {
    // The ids of the most useful shortcuts, best first.
    let topIDs: [String]
    // Well-known shortcuts that are not in the app's menus.
    let suggestions: [Suggestion]
}

// The reasons a ranking can fail. The panel shows a different line for each.
enum RankingError: Error, Equatable {
    case noKey          // no API key has been set yet
    case offline        // no internet connection
    case unauthorized   // the API key was not accepted
    case refused        // the model declined to answer
    case failed         // anything else
}

// Asks Claude which shortcuts of an app are the most useful.
// Only the app's name and its shortcut list are sent.
enum RankingClient {

    // The Claude model to use. Change it here if you want a different one.
    static let model = "claude-sonnet-5-5"

    // At most this many shortcuts are sent, so the request stays small.
    static let maxSent = 400

    private static let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!

    // Sends the request and returns Claude's answer.
    static func rank(appName: String, shortcuts: [Shortcut], apiKey: String?) async throws -> RankingResult {
        let key = (apiKey ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { throw RankingError.noKey }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.setValue(key, forHTTPHeaderField: "x-api-key")
        request.setValue("2026-10-21", forHTTPHeaderField: "anthropic-version")
        // Needed for the "fallbacks" field below.
        request.setValue("server-side-fallback-2026-07-01", forHTTPHeaderField: "anthropic-beta")
        request.httpBody = try requestBody(appName: appName, shortcuts: shortcuts)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            // The request never got an answer: no connection, or it took too long.
            throw RankingError.offline
        }

        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
        return try parse(data, statusCode: statusCode, shortcuts: shortcuts)
    }

    // Builds the JSON we send to Claude.
    static func requestBody(appName: String, shortcuts: [Shortcut]) throws -> Data {
        // The shape Claude's answer must have. The API guarantees it follows this.
        let schema: [String: Any] = [
            "type": "object",
            "properties": [
                "top": ["type": "array", "items": ["type": "integer"]],
                "extra": [
                    "type": "array",
                    "items": [
                        "type": "object",
                        "properties": [
                            "keys": ["type": "string"],
                            "description": ["type": "string"],
                        ],
                        "required": ["keys", "description"],
                        "additionalProperties": false,
                    ],
                ],
            ],
            "required": ["top", "extra"],
            "additionalProperties": false,
        ]

        let body: [String: Any] = [
            "model": model,
            "max_tokens": 8000,
            // If the model declines for safety reasons, the API retries once on another model.
            "fallbacks": "default",
            "output_config": [
                "effort": "low",
                "format": ["type": "json_schema", "schema": schema],
            ],
            "messages": [
                ["role": "user", "content": prompt(appName: appName, shortcuts: shortcuts)],
            ],
        ]
        return try JSONSerialization.data(withJSONObject: body)
    }

    // The question we ask Claude, with the numbered shortcut list.
    private static func prompt(appName: String, shortcuts: [Shortcut]) -> String {
        let lines = shortcuts.prefix(maxSent).enumerated().map { index, shortcut in
            "\(index). \(shortcut.id) — \(shortcut.keys)"
        }
        return """
        These are keyboard shortcuts from the menus of the macOS app "\(appName)". \
        Each line is: number. menu path > menu item — keys.

        \(lines.joined(separator: "\n"))

        Answer with two lists.

        "top": the numbers of up to 10 shortcuts from the list above that are most worth \
        knowing for someone who uses this app every day, most useful first. Prefer \
        shortcuts that save real time over ones everybody already knows, such as copy, \
        paste and quit.

        "extra": up to 8 well-known keyboard shortcuts of this app that are NOT in the list \
        above, for example ones the app does not show in its menus. Write "keys" with the \
        same symbols as the list (⌃ ⌥ ⇧ ⌘ followed by the key) and "description" as a few \
        plain words. Only include shortcuts you are sure exist in this app on macOS. If you \
        are not sure, or you do not know this app, return an empty list instead of guessing.
        """
    }

    // The parts of the API's answer that we read.
    private struct APIResponse: Decodable {
        let stop_reason: String?
        let content: [Block]

        struct Block: Decodable {
            let type: String
            let text: String?
        }
    }

    // The JSON Claude writes inside its answer, matching the schema above.
    private struct Answer: Decodable {
        let top: [Int]
        let extra: [Suggestion]
    }

    // Turns the API's reply into a RankingResult, or throws the matching RankingError.
    static func parse(_ data: Data, statusCode: Int, shortcuts: [Shortcut]) throws -> RankingResult {
        if statusCode == 401 { throw RankingError.unauthorized }
        guard statusCode == 200 else { throw RankingError.failed }

        guard let response = try? JSONDecoder().decode(APIResponse.self, from: data) else {
            throw RankingError.failed
        }
        if response.stop_reason == "refusal" { throw RankingError.refused }
        guard response.stop_reason == "end_turn" else { throw RankingError.failed }

        // The answer is the first block of type "text"; other blocks are skipped.
        guard let text = response.content.first(where: { $0.type == "text" })?.text,
              let answer = try? JSONDecoder().decode(Answer.self, from: Data(text.utf8)) else {
            throw RankingError.failed
        }

        // Turn the numbers back into shortcut ids, skipping repeats and numbers that don't exist.
        var topIDs: [String] = []
        for index in answer.top where shortcuts.indices.contains(index) {
            let id = shortcuts[index].id
            if !topIDs.contains(id) { topIDs.append(id) }
        }

        // Drop suggestions that are empty or that the menus already contain.
        let menuKeys = Set(shortcuts.map { normalized($0.keys) })
        let suggestions = answer.extra.filter { suggestion in
            let keys = normalized(suggestion.keys)
            let description = suggestion.description.trimmingCharacters(in: .whitespacesAndNewlines)
            return !keys.isEmpty && !description.isEmpty && !menuKeys.contains(keys)
        }

        return RankingResult(topIDs: Array(topIDs.prefix(10)), suggestions: Array(suggestions.prefix(8)))
    }

    // Makes "⌘ n" and "⌘N" compare as equal.
    private static func normalized(_ keys: String) -> String {
        keys.filter { !$0.isWhitespace }.uppercased()
    }
}
