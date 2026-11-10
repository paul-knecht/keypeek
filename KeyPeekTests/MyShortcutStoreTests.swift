import XCTest
@testable import KeyPeek

// Checks saving the shortcuts the user adds by hand, using a throwaway folder.
final class MyShortcutStoreTests: XCTestCase {

    private var directory: URL!
    private var store: MyShortcutStore!
    private let switchMode = MyShortcut(keys: "⌥⌘→", description: "Switch to Claude Code")

    override func setUp() {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("KeyPeekMyShortcutTests-\(UUID().uuidString)")
        store = MyShortcutStore(directory: directory)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: directory)
    }

    func testNothingSavedIsEmpty() {
        XCTAssertEqual(store.load(bundleID: "com.example.app"), [])
    }

    func testAddThenLoad() {
        store.add(switchMode, bundleID: "com.example.app")
        XCTAssertEqual(store.load(bundleID: "com.example.app"), [switchMode])
        XCTAssertEqual(store.load(bundleID: "com.example.other"), [])
    }

    func testAddingSameKeysReplacesTheOldEntry() {
        store.add(switchMode, bundleID: "com.example.app")
        store.add(MyShortcut(keys: "⌥⌘→", description: "New text"), bundleID: "com.example.app")
        XCTAssertEqual(store.load(bundleID: "com.example.app").map(\.description), ["New text"])
    }

    func testKeepsOrderOfAdding() {
        store.add(switchMode, bundleID: "com.example.app")
        store.add(MyShortcut(keys: "⌥⌘←", description: "Switch to Chat"), bundleID: "com.example.app")
        XCTAssertEqual(store.load(bundleID: "com.example.app").map(\.keys), ["⌥⌘→", "⌥⌘←"])
    }

    func testRemove() {
        store.add(switchMode, bundleID: "com.example.app")
        store.remove(keys: "⌥⌘→", bundleID: "com.example.app")
        XCTAssertEqual(store.load(bundleID: "com.example.app"), [])
    }

    func testCorruptFileIsEmpty() throws {
        store.add(switchMode, bundleID: "com.example.app")
        try Data("not json".utf8).write(to: directory.appendingPathComponent("com.example.app.json"))
        XCTAssertEqual(store.load(bundleID: "com.example.app"), [])
    }
}
