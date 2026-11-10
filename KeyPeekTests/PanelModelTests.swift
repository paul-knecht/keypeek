import XCTest
@testable import KeyPeek

// Checks the panel's logic without needing a real app or the network.
@MainActor
final class PanelModelTests: XCTestCase {

    func testGroupsByTopMenuInOrder() {
        let shortcuts = [
            Shortcut(menuPath: ["File"], title: "New", keys: "⌘N"),
            Shortcut(menuPath: ["Edit"], title: "Copy", keys: "⌘C"),
            Shortcut(menuPath: ["File", "Export"], title: "PDF", keys: "⌘E"),
        ]
        let groups = PanelModel.groups(from: shortcuts)
        XCTAssertEqual(groups.map(\.title), ["File", "Edit"])
        XCTAssertEqual(groups[0].shortcuts.map(\.title), ["New", "PDF"])
        XCTAssertEqual(groups[1].shortcuts.map(\.title), ["Copy"])
    }

    func testGroupsEmpty() {
        XCTAssertTrue(PanelModel.groups(from: []).isEmpty)
    }

    // MARK: - Ranking

    private let shortcuts = [
        Shortcut(menuPath: ["File"], title: "New Window", keys: "⌘N"),
        Shortcut(menuPath: ["Edit"], title: "Copy", keys: "⌘C"),
    ]
    private let result = RankingResult(
        topIDs: ["Edit > Copy"],
        suggestions: [Suggestion(keys: "⇧⌘.", description: "Show hidden files")]
    )
    private var directory: URL!
    private var store: RankingStore!
    private var myStore: MyShortcutStore!
    private var rankCalls = 0

    override func setUp() {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("KeyPeekPanelTests-\(UUID().uuidString)")
        store = RankingStore(directory: directory)
        myStore = MyShortcutStore(directory: directory.appendingPathComponent("mine"))
        rankCalls = 0
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: directory)
    }

    // A model whose "ask Claude" step is replaced by the given closure.
    private func makeModel(rank: @escaping (String) async throws -> RankingResult) -> PanelModel {
        PanelModel(store: store, myStore: myStore, loadKey: { "test-key" }, rank: { appName, _, _ in
            self.rankCalls += 1
            return try await rank(appName)
        })
    }

    func testResolveDropsMissingIDs() {
        let saved = RankingResult(topIDs: ["Edit > Copy", "Gone > Item", "File > New Window"], suggestions: [])
        XCTAssertEqual(PanelModel.resolve(saved, in: shortcuts).map(\.title), ["Copy", "New Window"])
    }

    func testMessageForEachError() {
        XCTAssertEqual(PanelModel.message(for: .noKey),
                       "Add an Anthropic API key from the right-click menu to see the most useful shortcuts.")
        XCTAssertEqual(PanelModel.message(for: .offline), "No internet connection. Showing all shortcuts.")
        XCTAssertEqual(PanelModel.message(for: .unauthorized),
                       "The API key was not accepted. Set it again from the right-click menu.")
        XCTAssertEqual(PanelModel.message(for: .refused), "Claude declined to rank this app.")
        XCTAssertEqual(PanelModel.message(for: .failed), "Ranking failed. Try “Re-rank this app” later.")
    }

    func testUsesSavedRankingWithoutCallingRank() async {
        store.save(result, bundleID: "a")
        let model = makeModel { _ in self.result }
        await model.show(appName: "A", bundleID: "a", shortcuts: shortcuts)
        XCTAssertEqual(rankCalls, 0)
        XCTAssertEqual(model.rankingState, .ready)
        XCTAssertEqual(model.top.map(\.title), ["Copy"])
        XCTAssertEqual(model.suggestions, result.suggestions)
    }

    func testRanksAndSavesOnFirstOpen() async {
        let model = makeModel { _ in self.result }
        await model.show(appName: "A", bundleID: "a", shortcuts: shortcuts)
        XCTAssertEqual(rankCalls, 1)
        XCTAssertEqual(model.rankingState, .ready)
        XCTAssertEqual(model.top.map(\.title), ["Copy"])
        XCTAssertEqual(store.load(bundleID: "a"), result)
    }

    func testErrorShowsMessageAndKeepsGroups() async {
        let model = makeModel { _ in throw RankingError.offline }
        await model.show(appName: "A", bundleID: "a", shortcuts: shortcuts)
        XCTAssertEqual(model.rankingState, .message("No internet connection. Showing all shortcuts."))
        XCTAssertFalse(model.groups.isEmpty)
        XCTAssertNil(store.load(bundleID: "a"))
    }

    func testLateResultForOtherAppIsNotShown() async {
        let gate = Gate()
        let model = makeModel { appName in
            if appName == "A" { return await gate.wait() }
            throw RankingError.noKey
        }

        // Start ranking app A; it hangs at the gate like a slow network request.
        let rankingA = Task { await model.show(appName: "A", bundleID: "a", shortcuts: self.shortcuts) }
        while !gate.isWaiting { await Task.yield() }

        // Meanwhile the panel is opened over app B.
        await model.show(appName: "B", bundleID: "b", shortcuts: shortcuts)

        // Now A's answer arrives.
        gate.open(with: result)
        await rankingA.value

        XCTAssertEqual(model.appName, "B")
        XCTAssertEqual(model.top, [])
        XCTAssertEqual(model.suggestions, [])
        XCTAssertEqual(model.rankingState, .message(PanelModel.message(for: .noKey)))
        XCTAssertEqual(store.load(bundleID: "a"), result)
    }

    func testReopeningWhileRankingDoesNotAskTwice() async {
        let gate = Gate()
        let model = makeModel { _ in await gate.wait() }

        let first = Task { await model.show(appName: "A", bundleID: "a", shortcuts: self.shortcuts) }
        while !gate.isWaiting { await Task.yield() }

        // The panel is closed and opened again over the same app before the answer arrived.
        await model.show(appName: "A", bundleID: "a", shortcuts: shortcuts)
        XCTAssertEqual(model.rankingState, .ranking)

        gate.open(with: result)
        await first.value

        XCTAssertEqual(rankCalls, 1)
        XCTAssertEqual(model.rankingState, .ready)
        XCTAssertEqual(model.top.map(\.title), ["Copy"])
    }

    func testNoShortcutsMakesNoRequest() async {
        let model = makeModel { _ in self.result }
        await model.show(appName: "A", bundleID: "a", shortcuts: [])
        XCTAssertEqual(rankCalls, 0)
        XCTAssertEqual(model.rankingState, .idle)
    }

    func testNoBundleIDMakesNoRequest() async {
        let model = makeModel { _ in self.result }
        await model.show(appName: "A", bundleID: nil, shortcuts: shortcuts)
        XCTAssertEqual(rankCalls, 0)
        XCTAssertEqual(model.rankingState, .idle)
        XCTAssertFalse(model.groups.isEmpty)
    }

    // MARK: - My shortcuts

    func testShowLoadsMyShortcutsForThatApp() async {
        myStore.add(MyShortcut(keys: "⌥⌘→", description: "Switch to Claude Code"), bundleID: "a")
        let model = makeModel { _ in self.result }

        await model.show(appName: "A", bundleID: "a", shortcuts: shortcuts)
        XCTAssertEqual(model.myShortcuts.map(\.keys), ["⌥⌘→"])

        await model.show(appName: "B", bundleID: "b", shortcuts: shortcuts)
        XCTAssertEqual(model.myShortcuts, [])
    }

    func testMyShortcutsShowEvenWhenTheAppHasNoMenuShortcuts() async {
        myStore.add(MyShortcut(keys: "⌥⌘→", description: "Switch to Claude Code"), bundleID: "a")
        let model = makeModel { _ in self.result }
        await model.show(appName: "A", bundleID: "a", shortcuts: [])
        XCTAssertEqual(model.myShortcuts.count, 1)
    }

    func testAddAndRemoveMyShortcutUpdatesThePanelAndTheFile() async {
        let model = makeModel { _ in self.result }
        await model.show(appName: "A", bundleID: "a", shortcuts: shortcuts)

        model.addMyShortcut(MyShortcut(keys: "⌥⌘→", description: "Switch to Claude Code"), bundleID: "a")
        XCTAssertEqual(model.myShortcuts.map(\.keys), ["⌥⌘→"])
        XCTAssertEqual(myStore.load(bundleID: "a").count, 1)

        model.removeMyShortcut(keys: "⌥⌘→")
        XCTAssertEqual(model.myShortcuts, [])
        XCTAssertEqual(myStore.load(bundleID: "a"), [])
    }

    func testAddingForAnotherAppDoesNotChangeThePanel() async {
        let model = makeModel { _ in self.result }
        await model.show(appName: "A", bundleID: "a", shortcuts: shortcuts)
        model.addMyShortcut(MyShortcut(keys: "⌘J", description: "Other app"), bundleID: "b")
        XCTAssertEqual(model.myShortcuts, [])
        XCTAssertEqual(myStore.load(bundleID: "b").count, 1)
    }

    func testMyShortcutsAreNeverSentForRanking() async {
        myStore.add(MyShortcut(keys: "⌥⌘→", description: "Private note"), bundleID: "a")
        var sent: [Shortcut] = []
        let model = PanelModel(store: store, myStore: myStore, loadKey: { "k" }, rank: { _, list, _ in
            sent = list
            return self.result
        })
        await model.show(appName: "A", bundleID: "a", shortcuts: shortcuts)
        XCTAssertEqual(sent, shortcuts)
    }

    func testRerankAsksAgainAndReplacesSavedResult() async {
        store.save(RankingResult(topIDs: ["File > New Window"], suggestions: []), bundleID: "a")
        let model = makeModel { _ in self.result }
        await model.show(appName: "A", bundleID: "a", shortcuts: shortcuts)
        XCTAssertEqual(model.top.map(\.title), ["New Window"])

        await model.rerankNow()

        XCTAssertEqual(rankCalls, 1)
        XCTAssertEqual(model.top.map(\.title), ["Copy"])
        XCTAssertEqual(store.load(bundleID: "a"), result)
    }
}

// Lets a test hold back a fake "network answer" until it chooses to release it.
@MainActor
private final class Gate {
    private var continuation: CheckedContinuation<RankingResult, Never>?
    var isWaiting: Bool { continuation != nil }

    func wait() async -> RankingResult {
        await withCheckedContinuation { continuation = $0 }
    }

    func open(with result: RankingResult) {
        continuation?.resume(returning: result)
        continuation = nil
    }
}
