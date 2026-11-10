import AppKit
import SwiftUI

// Owns the menu bar icon and the panel that opens from it.
@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {

    // The icon in the menu bar. We keep a reference so it doesn't disappear.
    var statusItem: NSStatusItem!

    // The small panel that opens under the icon on left-click.
    let popover = NSPopover()

    // The menu shown on right-click.
    let menu = NSMenu()

    // Knows which app was in front before the icon was clicked.
    let tracker = FrontAppTracker()

    // Holds what the panel shows.
    let model = PanelModel()

    // Where the API key is kept.
    let keychain = KeychainStore()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Create the menu bar icon.
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        // Tell the icon's button to call iconClicked for left AND right clicks.
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "keyboard", accessibilityDescription: "KeyPeek")
            button.target = self
            button.action = #selector(iconClicked)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        // The panel closes by itself when you click anywhere else.
        popover.behavior = .transient
        popover.contentSize = NSSize(width: 360, height: 480)
        popover.contentViewController = NSHostingController(rootView: PanelView(model: model))

        // Build the right-click menu.
        menu.addItem(NSMenuItem(title: "Re-rank this app", action: nil, keyEquivalent: ""))
        let keyItem = NSMenuItem(title: "Set API key…", action: #selector(setAPIKey), keyEquivalent: "")
        keyItem.target = self
        menu.addItem(keyItem)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
    }

    // Shows a small dialog where the user types their Anthropic API key.
    // The field hides what is typed, and the key goes straight into the Keychain.
    @objc func setAPIKey() {
        let alert = NSAlert()
        alert.messageText = "Anthropic API key"
        alert.informativeText = "The key is stored in your Mac's Keychain. Leave the field empty and press Save to remove a stored key."
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")

        let field = NSSecureTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
        alert.accessoryView = field
        alert.window.initialFirstResponder = field

        // A menu-bar-only app has to step forward, or the dialog opens behind other windows.
        NSApp.activate(ignoringOtherApps: true)

        guard alert.runModal() == .alertFirstButtonReturn else { return }
        let key = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if key.isEmpty {
            keychain.delete()
        } else {
            keychain.save(key)
        }
    }

    // Called for every click on the menu bar icon.
    @objc func iconClicked() {
        if NSApp.currentEvent?.type == .rightMouseUp {
            // Right-click: attach the menu just long enough to show it.
            // (If the menu stayed attached, left-clicks would open it too.)
            statusItem.menu = menu
            statusItem.button?.performClick(nil)
            statusItem.menu = nil
        } else {
            togglePopover()
        }
    }

    // Opens the panel under the icon, or closes it if it is already open.
    func togglePopover() {
        if popover.isShown {
            popover.close()
        } else if let button = statusItem.button {
            // Load the shortcuts of the app that was in front, then show the panel.
            model.open(for: tracker.current)
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }
}
