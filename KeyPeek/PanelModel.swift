import AppKit

// The shortcuts of one top-level menu, for example everything under "File".
struct MenuGroup: Identifiable {
    let id: String
    let title: String
    let shortcuts: [Shortcut]
}

// What the "Most useful" section is doing right now.
enum RankingState: Equatable {
    case idle               // nothing to rank
    case ranking            // waiting for Claude's answer
    case ready              // the ranking is shown
    case message(String)    // ranking didn't happen; the text says why
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
    @Published var top: [Shortcut] = []
    @Published var suggestions: [Suggestion] = []
    @Published var rankingState: RankingState = .idle

    // The three things the model needs from outside. They are passed in so
    // that tests can replace them with fakes.
    private let store: RankingStore
    private let loadKey: () -> String?
    private let rank: (String, [Shortcut], String?) async throws -> RankingResult

    // The app the panel is showing right now.
    private var currentPID: pid_t?
    private var currentBundleID: String?
    private var currentShortcuts: [Shortcut] = []

    // Apps we are waiting on an answer for, so we never ask twice at once.
    private var appsBeingRanked = Set<String>()

    init(store: RankingStore,
         loadKey: @escaping () -> String?,
         rank: @escaping (String, [Shortcut], String?) async throws -> RankingResult) {
        self.store = store
        self.loadKey = loadKey
        self.rank = rank
    }

    // Called each time the panel opens.
    func open(for app: NSRunningApplication?) {
        appName = app?.localizedName ?? "No app in front"
        appIcon = app?.icon
        needsPermission = !MenuReader.hasPermission
        groups = []
        top = []
        suggestions = []
        rankingState = .idle
        currentPID = app?.processIdentifier
        currentBundleID = app?.bundleIdentifier
        currentShortcuts = []

        guard let app, !needsPermission else { return }
        let pid = app.processIdentifier
        let name = appName
        let bundleID = app.bundleIdentifier
        isReading = true

        Task {
            // Reading menus can take a moment, so it runs in the background
            // and the menu bar never freezes.
            let shortcuts = await Task.detached {
                MenuFlattener.shortcuts(from: MenuReader.readMenuBar(pid: pid))
            }.value

            // If the panel was opened for a different app in the meantime, drop this result.
            guard pid == self.currentPID else { return }
            await self.show(appName: name, bundleID: bundleID, shortcuts: shortcuts)
        }
    }

    // Shows an app's shortcuts and then fills in the ranking: from the saved
    // file if there is one, otherwise by asking Claude once.
    func show(appName: String, bundleID: String?, shortcuts: [Shortcut]) async {
        self.appName = appName
        currentBundleID = bundleID
        currentShortcuts = shortcuts
        groups = Self.groups(from: shortcuts)
        isReading = false
        top = []
        suggestions = []

        // Nothing to rank, or no way to remember the answer for this app.
        guard let bundleID, !shortcuts.isEmpty else {
            rankingState = .idle
            return
        }

        if let saved = store.load(bundleID: bundleID) {
            apply(saved)
            return
        }

        rankingState = .ranking
        // A request for this app is already on its way; its answer will arrive below.
        guard !appsBeingRanked.contains(bundleID) else { return }
        appsBeingRanked.insert(bundleID)

        do {
            let result = try await rank(appName, shortcuts, loadKey())
            appsBeingRanked.remove(bundleID)
            store.save(result, bundleID: bundleID)
            // Only show the answer if the panel is still about the same app.
            if currentBundleID == bundleID { apply(result) }
        } catch {
            appsBeingRanked.remove(bundleID)
            if currentBundleID == bundleID {
                rankingState = .message(Self.message(for: error as? RankingError ?? .failed))
            }
        }
    }

    // Called by "Re-rank this app": forgets the saved answer and asks again.
    func rerank() {
        Task { await rerankNow() }
    }

    func rerankNow() async {
        guard let bundleID = currentBundleID, !appsBeingRanked.contains(bundleID) else { return }
        store.delete(bundleID: bundleID)
        await show(appName: appName, bundleID: bundleID, shortcuts: currentShortcuts)
    }

    // Puts a ranking on screen.
    private func apply(_ result: RankingResult) {
        top = Self.resolve(result, in: currentShortcuts)
        suggestions = result.suggestions
        rankingState = .ready
    }

    // Looks up the ranked ids in the current shortcut list. Ids that no longer
    // exist (the app's menus changed) are left out.
    static func resolve(_ result: RankingResult, in shortcuts: [Shortcut]) -> [Shortcut] {
        result.topIDs.compactMap { id in shortcuts.first { $0.id == id } }
    }

    // The line shown in the panel for each reason a ranking can fail.
    static func message(for error: RankingError) -> String {
        switch error {
        case .noKey:
            return "Add an Anthropic API key from the right-click menu to see the most useful shortcuts."
        case .offline:
            return "No internet connection. Showing all shortcuts."
        case .unauthorized:
            return "The API key was not accepted. Set it again from the right-click menu."
        case .refused:
            return "Claude declined to rank this app."
        case .failed:
            return "Ranking failed. Try “Re-rank this app” later."
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
