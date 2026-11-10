import XCTest
@testable import KeyPeek

// Checks saving and loading rankings, using a throwaway folder.
final class RankingStoreTests: XCTestCase {

    private var directory: URL!
    private var store: RankingStore!
    private let result = RankingResult(
        topIDs: ["File > New Window"],
        suggestions: [Suggestion(keys: "⇧⌘.", description: "Show hidden files")]
    )

    override func setUp() {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("KeyPeekTests-\(UUID().uuidString)")
            .appendingPathComponent("rankings")
        store = RankingStore(directory: directory)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: directory.deletingLastPathComponent())
    }

    func testRoundTrip() {
        store.save(result, bundleID: "com.apple.finder")
        XCTAssertEqual(store.load(bundleID: "com.apple.finder"), result)
    }

    func testMissingIsNil() {
        XCTAssertNil(store.load(bundleID: "com.example.nothing"))
    }

    func testCorruptFileIsNil() throws {
        store.save(result, bundleID: "com.apple.finder")
        let file = directory.appendingPathComponent("com.apple.finder.json")
        try Data("not json".utf8).write(to: file)
        XCTAssertNil(store.load(bundleID: "com.apple.finder"))
    }

    func testDeleteRemoves() {
        store.save(result, bundleID: "com.apple.finder")
        store.delete(bundleID: "com.apple.finder")
        XCTAssertNil(store.load(bundleID: "com.apple.finder"))
    }

    func testOddBundleIDIsSafeFileName() throws {
        store.save(result, bundleID: "../a/b:c")
        XCTAssertEqual(store.load(bundleID: "../a/b:c"), result)

        // Exactly one file, and it sits inside our folder.
        let files = try FileManager.default.contentsOfDirectory(atPath: directory.path)
        XCTAssertEqual(files, [".._a_b_c.json"])
        let parent = try FileManager.default.contentsOfDirectory(atPath: directory.deletingLastPathComponent().path)
        XCTAssertEqual(parent, ["rankings"])
    }
}
