import Foundation

// Turns the raw key data of a menu item into readable text like "⇧⌘.".
enum KeyFormatter {

    // Returns nil when the menu item has no key combination.
    static func string(cmdChar: String?, virtualKey: Int?, glyph: Int?, modifiers: Int) -> String? {
        guard let key = keyName(cmdChar: cmdChar, virtualKey: virtualKey, glyph: glyph) else {
            return nil
        }

        // The modifiers arrive as one number in which each bit is one key:
        // 1 = Shift, 2 = Option, 4 = Control. Command is always included
        // unless bit 8 is set.
        var text = ""
        if modifiers & 4 != 0 { text += "⌃" }
        if modifiers & 2 != 0 { text += "⌥" }
        if modifiers & 1 != 0 { text += "⇧" }
        if modifiers & 8 == 0 { text += "⌘" }
        return text + key
    }

    // Finds the name of the main key: a character, or a symbol for a special key.
    private static func keyName(cmdChar: String?, virtualKey: Int?, glyph: Int?) -> String? {
        if let char = cmdChar, !char.isEmpty {
            if let name = specialCharacters[char] {
                return name
            }
            // Ordinary characters are shown as they are. Invisible ones we don't
            // know are skipped, and the key code or glyph below is used instead.
            if !isInvisible(char) {
                return char.uppercased()
            }
        }
        if let virtualKey, let name = virtualKeys[virtualKey] {
            return name
        }
        if let glyph, let name = glyphs[glyph] {
            return name
        }
        return nil
    }

    // True for characters that have no visible shape: control characters and
    // the private range macOS uses for keys like arrows and F-keys.
    private static func isInvisible(_ char: String) -> Bool {
        char.unicodeScalars.contains { scalar in
            scalar.value < 0x20 || scalar.value == 0x7F || (0xF700...0xF8FF).contains(scalar.value)
        }
    }

    // Characters that stand for a special key and need a readable name.
    private static let specialCharacters: [String: String] = [
        " ": "Space", "\r": "↩", "\t": "⇥", "\u{8}": "⌫", "\u{7F}": "⌫", "\u{1B}": "⎋",
        "\u{F700}": "↑", "\u{F701}": "↓", "\u{F702}": "←", "\u{F703}": "→",
        "\u{F704}": "F1", "\u{F705}": "F2", "\u{F706}": "F3", "\u{F707}": "F4",
        "\u{F708}": "F5", "\u{F709}": "F6", "\u{F70A}": "F7", "\u{F70B}": "F8",
        "\u{F70C}": "F9", "\u{F70D}": "F10", "\u{F70E}": "F11", "\u{F70F}": "F12",
        "\u{F728}": "⌦", "\u{F729}": "↖", "\u{F72B}": "↘", "\u{F72C}": "⇞", "\u{F72D}": "⇟",
    ]

    // macOS key codes for keys that have no character.
    private static let virtualKeys: [Int: String] = [
        36: "↩", 48: "⇥", 49: "Space", 51: "⌫", 53: "⎋", 117: "⌦",
        123: "←", 124: "→", 125: "↓", 126: "↑",
        116: "⇞", 121: "⇟", 115: "↖", 119: "↘",
        122: "F1", 120: "F2", 99: "F3", 118: "F4", 96: "F5", 97: "F6",
        98: "F7", 100: "F8", 101: "F9", 109: "F10", 103: "F11", 111: "F12",
    ]

    // Menu glyph numbers, which some apps use instead of key codes.
    private static let glyphs: [Int: String] = [
        2: "⇥", 9: "Space", 10: "⌦", 11: "↩", 23: "⌫", 27: "⎋",
        100: "←", 101: "→", 104: "↑", 106: "↓",
        98: "⇞", 107: "⇟", 102: "↖", 105: "↘",
        111: "F1", 112: "F2", 113: "F3", 114: "F4", 115: "F5", 116: "F6",
        117: "F7", 118: "F8", 119: "F9", 120: "F10", 121: "F11", 122: "F12",
    ]
}
