import AppKit

// Remembers which app was in front most recently, not counting KeyPeek itself.
// The panel uses this to know whose shortcuts to show.
final class FrontAppTracker {

    private(set) var current: NSRunningApplication?

    init() {
        remember(NSWorkspace.shared.frontmostApplication)

        // macOS tells us every time another app comes to the front.
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
        ) { [weak self] notification in
            let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            self?.remember(app)
        }
    }

    private func remember(_ app: NSRunningApplication?) {
        guard let app, app.processIdentifier != ProcessInfo.processInfo.processIdentifier else { return }
        current = app
    }
}
