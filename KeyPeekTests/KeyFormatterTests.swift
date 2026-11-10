import XCTest
@testable import KeyPeek

// Checks that raw key data from the Accessibility API becomes readable text.
final class KeyFormatterTests: XCTestCase {

    func testCommandLetterIsUppercase() {
        XCTAssertEqual(KeyFormatter.string(cmdChar: "n", virtualKey: nil, glyph: nil, modifiers: 0), "⌘N")
    }

    func testShiftCommand() {
        XCTAssertEqual(KeyFormatter.string(cmdChar: ".", virtualKey: nil, glyph: nil, modifiers: 1), "⇧⌘.")
    }

    func testControlOptionCommandOrder() {
        XCTAssertEqual(KeyFormatter.string(cmdChar: "f", virtualKey: nil, glyph: nil, modifiers: 6), "⌃⌥⌘F")
    }

    func testNoCommandBit() {
        XCTAssertEqual(KeyFormatter.string(cmdChar: "g", virtualKey: nil, glyph: nil, modifiers: 8), "G")
    }

    func testDeleteKeyFromVirtualKey() {
        XCTAssertEqual(KeyFormatter.string(cmdChar: nil, virtualKey: 51, glyph: nil, modifiers: 0), "⌘⌫")
    }

    func testArrowKeyFromVirtualKey() {
        XCTAssertEqual(KeyFormatter.string(cmdChar: nil, virtualKey: 126, glyph: nil, modifiers: 2), "⌥⌘↑")
    }

    func testFunctionKeyFromVirtualKey() {
        XCTAssertEqual(KeyFormatter.string(cmdChar: nil, virtualKey: 122, glyph: nil, modifiers: 8), "F1")
    }

    func testKeyFromGlyphWhenNoVirtualKey() {
        // Glyph 23 is the Delete (backspace) symbol in menus.
        XCTAssertEqual(KeyFormatter.string(cmdChar: nil, virtualKey: nil, glyph: 23, modifiers: 0), "⌘⌫")
    }

    func testSpaceCharIsSpelledOut() {
        XCTAssertEqual(KeyFormatter.string(cmdChar: " ", virtualKey: nil, glyph: nil, modifiers: 0), "⌘Space")
    }

    func testArrowCharBecomesArrowSymbol() {
        // Some apps report arrow keys as a special character instead of a key code.
        XCTAssertEqual(KeyFormatter.string(cmdChar: "\u{F702}", virtualKey: nil, glyph: nil, modifiers: 0), "⌘←")
    }

    func testNoKeyIsNil() {
        XCTAssertNil(KeyFormatter.string(cmdChar: nil, virtualKey: nil, glyph: nil, modifiers: 0))
    }

    func testEmptyCharIsNil() {
        XCTAssertNil(KeyFormatter.string(cmdChar: "", virtualKey: nil, glyph: nil, modifiers: 0))
    }

    func testUnknownVirtualKeyIsNil() {
        XCTAssertNil(KeyFormatter.string(cmdChar: nil, virtualKey: 9999, glyph: nil, modifiers: 0))
    }

    func testShortcutIDJoinsPathAndTitle() {
        let shortcut = Shortcut(menuPath: ["View", "Sort By"], title: "Name", keys: "⌃⌥⌘1")
        XCTAssertEqual(shortcut.id, "View > Sort By > Name")
    }
}
