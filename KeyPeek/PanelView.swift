import SwiftUI

// What the panel looks like. It only displays what PanelModel holds.
struct PanelView: View {
    @ObservedObject var model: PanelModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            content
        }
        .frame(width: 360, height: 480)
    }

    // The app's icon and name at the top.
    private var header: some View {
        HStack(spacing: 8) {
            if let icon = model.appIcon {
                Image(nsImage: icon).resizable().frame(width: 24, height: 24)
            }
            Text(model.appName).font(.headline)
            Spacer()
        }
        .padding(12)
    }

    // Everything below the header: one of three states.
    @ViewBuilder
    private var content: some View {
        if model.needsPermission {
            permissionMessage
        } else if model.groups.isEmpty && model.myShortcuts.isEmpty {
            Text(emptyText)
                .foregroundStyle(.secondary)
                .padding(12)
            Spacer()
        } else {
            shortcutList
        }
    }

    // Shown in place of the list while it is empty.
    private var emptyText: String {
        model.isReading ? "Reading shortcuts…" : "No shortcuts found in this app's menus."
    }

    private var permissionMessage: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("KeyPeek needs the Accessibility permission to read the shortcuts of other apps. It only reads menus and changes nothing.")
            Button("Open System Settings") {
                MenuReader.openPermissionSettings()
            }
            Spacer()
        }
        .padding(12)
    }

    private var shortcutList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 4) {
                mine
                mostUseful
                notInTheMenus

                sectionTitle("All shortcuts")
                if model.groups.isEmpty {
                    Text(emptyText).foregroundStyle(.secondary)
                }
                ForEach(model.groups) { group in
                    Text(group.title)
                        .font(.subheadline.bold())
                        .foregroundStyle(.secondary)
                        .padding(.top, 8)
                    ForEach(group.shortcuts) { shortcut in
                        ShortcutRow(title: shortcut.title,
                                    detail: shortcut.menuPath.dropFirst().joined(separator: " > "),
                                    keys: shortcut.keys)
                    }
                }
            }
            .padding(12)
        }
    }

    // The shortcuts the user added by hand. Each has a small button to remove it.
    @ViewBuilder
    private var mine: some View {
        if !model.myShortcuts.isEmpty {
            sectionTitle("My shortcuts")
            ForEach(model.myShortcuts) { shortcut in
                HStack {
                    ShortcutRow(title: shortcut.description, detail: "", keys: shortcut.keys)
                    Button {
                        model.removeMyShortcut(keys: shortcut.keys)
                    } label: {
                        Image(systemName: "xmark.circle")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .help("Remove this shortcut")
                }
            }
            Spacer().frame(height: 12)
        }
    }

    // The ranked shortcuts, or one line saying why there is no ranking.
    @ViewBuilder
    private var mostUseful: some View {
        switch model.rankingState {
        case .idle:
            EmptyView()
        case .ranking:
            sectionTitle("Most useful")
            Text("Ranking…").foregroundStyle(.secondary).padding(.bottom, 12)
        case .message(let text):
            sectionTitle("Most useful")
            Text(text).foregroundStyle(.secondary).padding(.bottom, 12)
        case .ready:
            if !model.top.isEmpty {
                sectionTitle("Most useful")
                ForEach(model.top) { shortcut in
                    ShortcutRow(title: shortcut.title,
                                detail: shortcut.menuPath.joined(separator: " > "),
                                keys: shortcut.keys)
                }
                Spacer().frame(height: 12)
            }
        }
    }

    // Shortcuts Claude suggested that the menus don't list. They get their own
    // section and a warning, because the app cannot check them.
    @ViewBuilder
    private var notInTheMenus: some View {
        if !model.suggestions.isEmpty {
            sectionTitle("Not in the menus")
            Text("Suggested by Claude. Not checked, may be wrong.")
                .font(.caption)
                .foregroundStyle(.secondary)
            ForEach(model.suggestions, id: \.keys) { suggestion in
                ShortcutRow(title: suggestion.description, detail: "", keys: suggestion.keys)
            }
            Spacer().frame(height: 12)
        }
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text).font(.title3.bold())
    }
}

// One line in the list: what the shortcut does on the left, its keys on the right.
struct ShortcutRow: View {
    let title: String
    let detail: String
    let keys: String

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 0) {
                Text(title)
                if !detail.isEmpty {
                    Text(detail).font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
            Text(keys).font(.system(.body, design: .monospaced))
        }
    }
}
