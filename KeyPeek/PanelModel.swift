import AppKit

// The shortcuts of one top-level menu, for example everything under "File".
struct MenuGroup: Identifiable {
    let id: String
    let title: String
    let shortcuts: [Shortcut]
}

// Holds everything the panel shows. When a value marked @Published changes,
// the panel redraws itself.
@MainActor
final class PanelModel: ObservableObject {

    @Published var appName = ""
    @Published var appIcon: NSImage?
    @Published var needsPermission = false
    @Published var isReading = false
    @Published var groups: [MenuGroup] = []

    // The process ID of the app the panel is showing right now.
    private var currentPID: pid_t?

    // Called each time the panel opens.
    func open(for app: NSRunningApplication?) {
        appName = app?.localizedName ?? "No app in front"
        appIcon = app?.icon
        needsPermission = !MenuReader.hasPermission
        groups = []
        currentPID = app?.processIdentifier

        guard let app, !needsPermission else { return }
        let pid = app.processIdentifier
        isReading = true

        Task {
            // Reading menus can take a moment, so it runs in the background
            // and the menu bar never freezes.
            let shortcuts = await Task.detached {
                MenuFlattener.shortcuts(from: MenuReader.readMenuBar(pid: pid))
            }.value

            // If the panel was opened for a different app in the meantime, drop this result.
            guard pid == self.currentPID else { return }
            self.groups = Self.groups(from: shortcuts)
            self.isReading = false
        }
    }

    // Sorts shortcuts into groups by their top-level menu, keeping menu order.
    static func groups(from shortcuts: [Shortcut]) -> [MenuGroup] {
        var titles: [String] = []
        var byTitle: [String: [Shortcut]] = [:]
        for shortcut in shortcuts {
            let title = shortcut.menuPath.first ?? ""
            if byTitle[title] == nil { titles.append(title) }
            byTitle[title, default: []].append(shortcut)
        }
        return titles.map { MenuGroup(id: $0, title: $0, shortcuts: byTitle[$0] ?? []) }
    }
}
