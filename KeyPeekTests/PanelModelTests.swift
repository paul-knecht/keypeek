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
}
