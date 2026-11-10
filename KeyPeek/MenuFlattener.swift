import Foundation

// Turns the tree of an app's menus into one flat list of shortcuts.
// This file does no Accessibility calls, so it is easy to test.
enum MenuFlattener {

    // menuBarItems are the top-level menus in order: Apple, the app's own menu, File, Edit, ...
    static func shortcuts(from menuBarItems: [MenuNode]) -> [Shortcut] {
        var result: [Shortcut] = []
        var seenIDs = Set<String>()

        // dropFirst skips the Apple menu, which is the same in every app.
        for (index, menu) in menuBarItems.enumerated().dropFirst() {
            // The second menu is the app's own menu (the one named after the app).
            collect(from: menu.children, path: [menu.title], isAppMenu: index == 1,
                    into: &result, seenIDs: &seenIDs)
        }
        return result
    }

    // Walks one menu and its submenus, adding every item that has a key combination.
    private static func collect(from items: [MenuNode], path: [String], isAppMenu: Bool,
                                into result: inout [Shortcut], seenIDs: inout Set<String>) {
        for item in items {
            // Services can contain names the user made up, so we leave the whole submenu out.
            // Its title depends on the Mac's language ("Dienste" in German), so we also
            // skip every submenu of the app's own menu, which is where Services lives.
            if item.title == "Services" { continue }
            if isAppMenu && !item.children.isEmpty { continue }

            let keys = KeyFormatter.string(cmdChar: item.cmdChar, virtualKey: item.cmdVirtualKey,
                                           glyph: item.cmdGlyph, modifiers: item.cmdModifiers)
            if let keys, !item.title.isEmpty {
                let shortcut = Shortcut(menuPath: path, title: item.title, keys: keys)
                // If the same item appears twice, keep only the first one.
                if seenIDs.insert(shortcut.id).inserted {
                    result.append(shortcut)
                }
            }

            // A submenu: go one level deeper and remember how we got there.
            if !item.children.isEmpty {
                collect(from: item.children, path: path + [item.title], isAppMenu: false,
                        into: &result, seenIDs: &seenIDs)
            }
        }
    }
}
