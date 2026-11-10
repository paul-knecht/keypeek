import AppKit

// Owns the menu bar icon and the panel that opens from it.
class AppDelegate: NSObject, NSApplicationDelegate {

    // The icon in the menu bar. We keep a reference so it doesn't disappear.
    var statusItem: NSStatusItem!

    // The small panel that opens under the icon on left-click.
    let popover = NSPopover()

    // The menu shown on right-click.
    let menu = NSMenu()

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
        popover.contentViewController = NSViewController()
        popover.contentViewController?.view = NSView()

        // Build the right-click menu.
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
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
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }
}
