import Foundation

// Saves Claude's answer for each app as a small file, so the app only
// has to ask once per app. Files live in
// ~/Library/Application Support/KeyPeek/rankings/.
struct RankingStore {

    let directory: URL

    init(directory: URL = RankingStore.defaultDirectory) {
        self.directory = directory
    }

    static var defaultDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("KeyPeek")
            .appendingPathComponent("rankings")
    }

    // Returns the saved ranking for an app, or nil if there is none
    // or the file can't be read.
    func load(bundleID: String) -> RankingResult? {
        guard let data = try? Data(contentsOf: file(for: bundleID)) else { return nil }
        return try? JSONDecoder().decode(RankingResult.self, from: data)
    }

    // Saves (or replaces) the ranking for an app.
    func save(_ result: RankingResult, bundleID: String) {
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        if let data = try? JSONEncoder().encode(result) {
            try? data.write(to: file(for: bundleID), options: .atomic)
        }
    }

    // Removes the saved ranking for an app.
    func delete(bundleID: String) {
        try? FileManager.default.removeItem(at: file(for: bundleID))
    }

    // The file for one app.
    private func file(for bundleID: String) -> URL {
        directory.appendingPathComponent(SafeFileName.json(for: bundleID))
    }
}
