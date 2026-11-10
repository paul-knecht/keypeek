import AppKit
import ApplicationServices

// Reads another app's menus through the macOS Accessibility API.
// This only reads; it never clicks or changes anything in the other app.
enum MenuReader {

    // True once the user has allowed KeyPeek under
    // System Settings > Privacy & Security > Accessibility.
    static var hasPermission: Bool {
        AXIsProcessTrusted()
    }

    // Asks macOS to add KeyPeek to the Accessibility list (macOS shows its own
    // dialog the first time) and opens that page in System Settings.
    static func openPermissionSettings() {
        let prompt = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        _ = AXIsProcessTrustedWithOptions([prompt: true] as CFDictionary)

        let address = "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        if let url = URL(string: address) {
            NSWorkspace.shared.open(url)
        }
    }

    // Returns the top-level menus of the app with this process ID, each with its items.
    // If anything goes wrong (no permission, app not answering), it returns what it
    // has read so far, which may be an empty list.
    static func readMenuBar(pid: pid_t) -> [MenuNode] {
        let app = AXUIElementCreateApplication(pid)
        // Don't wait longer than 2 seconds for an app that isn't answering.
        AXUIElementSetMessagingTimeout(app, 2)

        guard let menuBarValue = value(of: app, kAXMenuBarAttribute),
              CFGetTypeID(menuBarValue) == AXUIElementGetTypeID() else {
            return []
        }
        let menuBar = menuBarValue as! AXUIElement

        // Stop reading after 5 seconds in total, whatever happens.
        let deadline = Date().addingTimeInterval(5)
        return children(of: menuBar).map { node(from: $0, deadline: deadline) }
    }

    // Builds a MenuNode for one menu or menu item, including everything inside it.
    private static func node(from element: AXUIElement, deadline: Date) -> MenuNode {
        let title = value(of: element, kAXTitleAttribute) as? String ?? ""

        var items: [MenuNode] = []
        if Date() < deadline {
            // A menu's items sit one level down, inside a single "menu" element.
            // We skip that in-between level so children are the items themselves.
            var inner = children(of: element)
            if inner.count == 1, value(of: inner[0], kAXRoleAttribute) as? String == kAXMenuRole {
                inner = children(of: inner[0])
            }
            items = inner.map { node(from: $0, deadline: deadline) }
        }

        return MenuNode(
            title: title,
            cmdChar: value(of: element, kAXMenuItemCmdCharAttribute) as? String,
            cmdVirtualKey: value(of: element, kAXMenuItemCmdVirtualKeyAttribute) as? Int,
            cmdGlyph: value(of: element, kAXMenuItemCmdGlyphAttribute) as? Int,
            cmdModifiers: value(of: element, kAXMenuItemCmdModifiersAttribute) as? Int ?? 0,
            children: items
        )
    }

    // Reads one attribute of an element, or nil if it has none.
    private static func value(of element: AXUIElement, _ attribute: String) -> AnyObject? {
        var result: AnyObject?
        let error = AXUIElementCopyAttributeValue(element, attribute as CFString, &result)
        return error == .success ? result : nil
    }

    // Reads the elements directly inside an element.
    private static func children(of element: AXUIElement) -> [AXUIElement] {
        value(of: element, kAXChildrenAttribute) as? [AXUIElement] ?? []
    }
}
