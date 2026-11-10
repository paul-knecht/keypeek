import XCTest
@testable import KeyPeek

// Checks that a tree of menus becomes the right flat list of shortcuts.
final class MenuFlattenerTests: XCTestCase {

    // Shorthand for a menu item. modifiers 0 means "Command only".
    private func item(_ title: String, key: String? = nil, children: [MenuNode] = []) -> MenuNode {
        MenuNode(title: title, cmdChar: key, cmdVirtualKey: nil, cmdGlyph: nil, cmdModifiers: 0, children: children)
    }

    // A small menu bar shaped like a real one: Apple, the app's own menu, File, View.
    private var menuBar: [MenuNode] {
        [
            item("Apple", children: [item("Lock Screen", key: "q")]),
            item("Finder", children: [
                item("Settings…", key: ","),
                item("Services", children: [item("My Private Service", key: "p")]),
                item("Hide Finder", key: "h"),
            ]),
            item("File", children: [
                item("New Window", key: "n"),
                item("Open Recent", children: [item("Secret Document.txt")]),
                item("New Window", key: "t"),
                item("", key: "x"),
            ]),
            item("View", children: [
                item("Sort By", children: [item("Name", key: "1")]),
            ]),
        ]
    }

    func testSkipsAppleMenu() {
        let titles = MenuFlattener.shortcuts(from: menuBar).map(\.title)
        XCTAssertFalse(titles.contains("Lock Screen"))
    }

    func testSkipsServices() {
        let titles = MenuFlattener.shortcuts(from: menuBar).map(\.title)
        XCTAssertFalse(titles.contains("My Private Service"))
    }

    func testSkipsServicesInOtherLanguages() {
        // On a German Mac the submenu is called "Dienste". Any submenu inside
        // the app's own menu is skipped, whatever it is called.
        let german = [
            item("Apple"),
            item("Finder", children: [
                item("Einstellungen …", key: ","),
                item("Dienste", children: [item("Mein privater Dienst", key: "p")]),
            ]),
            item("Ablage", children: [
                item("Öffnen mit", children: [item("Vorschau", key: "o")]),
            ]),
        ]
        let titles = MenuFlattener.shortcuts(from: german).map(\.title)
        XCTAssertEqual(titles, ["Einstellungen …", "Vorschau"])
    }

    func testDropsItemsWithoutShortcut() {
        let titles = MenuFlattener.shortcuts(from: menuBar).map(\.title)
        XCTAssertFalse(titles.contains("Secret Document.txt"))
        XCTAssertFalse(titles.contains("Open Recent"))
    }

    func testDropsItemsWithEmptyTitle() {
        let titles = MenuFlattener.shortcuts(from: menuBar).map(\.title)
        XCTAssertFalse(titles.contains(""))
    }

    func testNestedPath() {
        let name = MenuFlattener.shortcuts(from: menuBar).first { $0.title == "Name" }
        XCTAssertEqual(name?.menuPath, ["View", "Sort By"])
        XCTAssertEqual(name?.id, "View > Sort By > Name")
        XCTAssertEqual(name?.keys, "⌘1")
    }

    func testKeepsMenuOrder() {
        let titles = MenuFlattener.shortcuts(from: menuBar).map(\.title)
        XCTAssertEqual(titles, ["Settings…", "Hide Finder", "New Window", "Name"])
    }

    func testDuplicateIdKeepsFirst() {
        let newWindows = MenuFlattener.shortcuts(from: menuBar).filter { $0.title == "New Window" }
        XCTAssertEqual(newWindows.map(\.keys), ["⌘N"])
    }

    func testEmptyInput() {
        XCTAssertEqual(MenuFlattener.shortcuts(from: []), [])
    }
}
