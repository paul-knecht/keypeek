import AppKit

// The small dialog behind "Add my shortcut…": the user presses the key
// combination and types what it does.
enum AddShortcutDialog {

    // Shows the dialog and returns the new shortcut, or nil if it was cancelled
    // or left incomplete.
    @MainActor
    static func run(appName: String) -> MyShortcut? {
        let alert = NSAlert()
        alert.messageText = "Add a shortcut for \(appName)"
        alert.informativeText = "It is saved on this Mac only and shown at the top of the panel for this app."
        alert.addButton(withTitle: "Add")
        alert.addButton(withTitle: "Cancel")

        let recorder = KeyRecorderView(frame: NSRect(x: 0, y: 0, width: 300, height: 28))
        let description = NSTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
        description.placeholderString = "What it does, for example: Switch to Claude Code"

        // Stack the two inputs with a label above each.
        let stack = NSStackView(views: [
            NSTextField(labelWithString: "Click the box, then press the shortcut:"),
            recorder,
            NSTextField(labelWithString: "What it does:"),
            description,
        ])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 6
        stack.frame = NSRect(x: 0, y: 0, width: 300, height: 110)
        recorder.widthAnchor.constraint(equalToConstant: 300).isActive = true
        recorder.heightAnchor.constraint(equalToConstant: 28).isActive = true
        description.widthAnchor.constraint(equalToConstant: 300).isActive = true
        alert.accessoryView = stack
        alert.window.initialFirstResponder = recorder

        // A menu-bar-only app has to step forward, or the dialog opens behind other windows.
        NSApp.activate(ignoringOtherApps: true)

        guard alert.runModal() == .alertFirstButtonReturn else { return nil }
        let text = description.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let keys = recorder.keys, !text.isEmpty else { return nil }
        return MyShortcut(keys: keys, description: text)
    }
}

// A box that shows the key combination the user presses while it is selected.
final class KeyRecorderView: NSView {

    // The recorded combination as text, for example "⌥⌘→". Nil until a key is pressed.
    private(set) var keys: String?

    private let label = NSTextField(labelWithString: "Press keys…")

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.cornerRadius = 6
        layer?.borderWidth = 1
        label.alignment = .center
        label.frame = bounds.insetBy(dx: 4, dy: 5)
        label.autoresizingMask = [.width, .height]
        addSubview(label)
        updateBorder(selected: false)
    }

    required init?(coder: NSCoder) {
        fatalError("KeyRecorderView is only created in code")
    }

    // Allows the box to be "selected" so that key presses go to it.
    override var acceptsFirstResponder: Bool { true }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
    }

    override func becomeFirstResponder() -> Bool {
        updateBorder(selected: true)
        return true
    }

    override func resignFirstResponder() -> Bool {
        updateBorder(selected: false)
        return true
    }

    // Ordinary key presses arrive here.
    override func keyDown(with event: NSEvent) {
        if !record(event) { super.keyDown(with: event) }
    }

    // Presses that include ⌘ arrive here instead, before menus get them.
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard window?.firstResponder === self else { return false }
        return record(event)
    }

    // Stores the pressed combination. Returns false for keys we leave alone.
    private func record(_ event: NSEvent) -> Bool {
        let flags = event.modifierFlags.intersection([.command, .option, .control, .shift])

        // Without ⌘, ⌥ or ⌃, keep Tab, Return and Escape working as usual in the dialog.
        let plainKeys: Set<UInt16> = [36, 48, 53, 76]
        if flags.isDisjoint(with: [.command, .option, .control]) && plainKeys.contains(event.keyCode) {
            return false
        }

        guard let text = KeyFormatter.string(pressedCharacters: event.charactersIgnoringModifiers ?? "",
                                             keyCode: Int(event.keyCode), flags: flags) else {
            return false
        }
        keys = text
        label.stringValue = text
        return true
    }

    private func updateBorder(selected: Bool) {
        layer?.borderColor = (selected ? NSColor.controlAccentColor : NSColor.separatorColor).cgColor
    }
}
