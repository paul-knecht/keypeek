import Foundation

// One keyboard shortcut read from an app's menus,
// for example File > New Window with the keys "⌘N".
struct Shortcut: Equatable, Identifiable {
    // A unique name built from where the item sits in the menus,
    // for example "View > Sort By > Name".
    let id: String
    // The menus you go through to reach the item, for example ["View", "Sort By"].
    let menuPath: [String]
    // The menu item's title, for example "Name".
    let title: String
    // The key combination as text, for example "⇧⌘.".
    let keys: String

    init(menuPath: [String], title: String, keys: String) {
        self.id = menuPath.joined(separator: " > ") + " > " + title
        self.menuPath = menuPath
        self.title = title
        self.keys = keys
    }
}

// A shortcut suggested by Claude that is not in the app's menus.
// The app cannot check it, so it is always shown separately.
struct Suggestion: Equatable, Codable {
    let keys: String
    let description: String
}

// A shortcut the user added by hand for one app, for shortcuts that
// neither the menus nor Claude know about.
struct MyShortcut: Equatable, Codable, Identifiable {
    let keys: String
    let description: String
    var id: String { keys }
}

// One entry of an app's menu bar as the Accessibility API reports it:
// a menu, a submenu, or a single menu item.
struct MenuNode {
    let title: String
    // The raw pieces of the key combination. Any of them can be missing.
    let cmdChar: String?
    let cmdVirtualKey: Int?
    let cmdGlyph: Int?
    let cmdModifiers: Int
    // The items inside this menu (empty for a plain menu item).
    let children: [MenuNode]
}
