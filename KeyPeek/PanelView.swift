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
        } else if model.groups.isEmpty {
            Text(model.isReading ? "Reading shortcuts…" : "No shortcuts found in this app's menus.")
                .foregroundStyle(.secondary)
                .padding(12)
            Spacer()
        } else {
            shortcutList
        }
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
                sectionTitle("All shortcuts")
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
