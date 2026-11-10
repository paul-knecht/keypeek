import Foundation

// Saves the shortcuts the user added by hand, one small file per app, in
// ~/Library/Application Support/KeyPeek/my-shortcuts/.
// These never leave the Mac; they are not sent to Claude.
struct MyShortcutStore {

    let directory: URL

    init(directory: URL = MyShortcutStore.defaultDirectory) {
        self.directory = directory
    }

    static var defaultDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("KeyPeek")
            .appendingPathComponent("my-shortcuts")
    }

    // Returns the user's shortcuts for an app, oldest first. Empty if there
    // are none or the file can't be read.
    func load(bundleID: String) -> [MyShortcut] {
        guard let data = try? Data(contentsOf: file(for: bundleID)),
              let shortcuts = try? JSONDecoder().decode([MyShortcut].self, from: data) else {
            return []
        }
        return shortcuts
    }

    // Adds a shortcut. If one with the same keys exists, it is replaced.
    func add(_ shortcut: MyShortcut, bundleID: String) {
        var shortcuts = load(bundleID: bundleID)
        if let index = shortcuts.firstIndex(where: { $0.keys == shortcut.keys }) {
            shortcuts[index] = shortcut
        } else {
            shortcuts.append(shortcut)
        }
        write(shortcuts, bundleID: bundleID)
    }

    // Removes the shortcut with these keys.
    func remove(keys: String, bundleID: String) {
        let shortcuts = load(bundleID: bundleID).filter { $0.keys != keys }
        write(shortcuts, bundleID: bundleID)
    }

    private func write(_ shortcuts: [MyShortcut], bundleID: String) {
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        if let data = try? JSONEncoder().encode(shortcuts) {
            try? data.write(to: file(for: bundleID), options: .atomic)
        }
    }

    private func file(for bundleID: String) -> URL {
        directory.appendingPathComponent(SafeFileName.json(for: bundleID))
    }
}
