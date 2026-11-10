# KeyPeek (Shortcut Viewer) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A macOS menu bar app that shows the keyboard shortcuts of the app in front, with the most useful ones (ranked by Claude Sonnet) at the top and Claude-suggested shortcuts that are not in the menus in their own labelled section.

**Architecture:** An `NSStatusItem` opens an `NSPopover` whose content is one SwiftUI view driven by a `PanelModel`. Shortcuts are read live through the Accessibility API into a plain tree, then flattened by pure, tested code. One HTTPS request per app asks Claude for a ranking and suggestions; the result is saved as JSON per app and reused.

**Tech Stack:** Swift 5, AppKit (`NSStatusItem`, `NSPopover`), SwiftUI for the popover content only, ApplicationServices (Accessibility), Security (Keychain), `URLSession`, XCTest. No third-party libraries.

**Spec:** `~/Developer/dock/docs/superpowers/specs/2026-11-10-shortcut-viewer-design.md` — Task 1 copies it, and this plan, into the new repo. Read it before starting.

## Global Constraints

- New repo at `~/Developer/keypeek`. Local only: no remotes, no pushing.
- Copy `~/Developer/dock/CLAUDE.md`, `.gitignore` and `.claude/settings.json` unchanged. The owner is a beginner: after each task, explain in plain language what was done and why; explain each commit, branch and merge in one sentence.
- Work on branch `feature/shortcut-viewer`; merge into `main` locally with `--no-ff` at the end.
- End every commit message with `Co-Authored-By: Claude Fable 5.2 <noreply@anthropic.com>`.
- macOS 27, Xcode 27.2. Deployment target macOS 14.0. App Sandbox off. Signed to run locally (`CODE_SIGN_IDENTITY = "-"`). Menu-bar-only (`LSUIElement = YES`). Bundle identifier `local.keypeek`.
- Model the Xcode project on `~/Developer/dock/DockToggle.xcodeproj/project.pbxproj` (file-system-synchronized groups, generated Info.plist), plus a hosted unit test target `KeyPeekTests` and a shared scheme `KeyPeek` so `xcodebuild test` works.
- Build: `xcodebuild -project KeyPeek.xcodeproj -scheme KeyPeek -derivedDataPath build build`. Test: same with `test` instead of the final `build`.
- Keep code simple: small files, plain names, a comment above each type and non-obvious function saying what it is for.
- The API key never appears in a source file, a plain file, a log line, a commit, or a chat message. The owner types it into the app themselves; Claude never asks for it or handles it.
- Only the app's name and its shortcut list (menu path, title, key combination) are sent to Anthropic.
- Suggested shortcuts are never shown in the same section as shortcuts read from the menus.
- Toggling or clicking in other apps to test is fine; reading Finder's menus is the standard manual check.
- Before writing any Claude API code (Task 6), load the `claude-api` skill and check the request shape below against it; where they differ, the skill wins.

## Review Focus

1. The front app is hung or quits while its menus are being read → the panel shows "No shortcuts found in this app's menus." within about 2 seconds, never a frozen menu bar. (Task 3: messaging timeout; Task 4: reading off the main thread.)
2. A ranking for app A arrives after the owner has opened the panel over app B → A's result is saved for A and not shown for B. (Task 8 test.)
3. The API key is wrong or revoked (HTTP 401) → the full list still shows, with the 401 line from the copy table. (Task 6 test.)
4. An app with several hundred shortcuts → all are listed; the request still succeeds because only the first 400 are sent. (Task 6 test.)
5. A saved ranking file is corrupt or from an older format → treated as "not ranked yet", not a crash. (Task 7 test.)

## File Structure

| File | Responsibility |
|---|---|
| `KeyPeek/main.swift` | Starts the app (as in DockToggle) |
| `KeyPeek/AppDelegate.swift` | Status item, popover, right-click menu, API key dialog |
| `KeyPeek/FrontAppTracker.swift` | Remembers the last app in front that isn't KeyPeek |
| `KeyPeek/Shortcut.swift` | `Shortcut`, `Suggestion`, `MenuNode` value types |
| `KeyPeek/KeyFormatter.swift` | Turns Accessibility key data into "⇧⌘." strings |
| `KeyPeek/MenuFlattener.swift` | Pure: `MenuNode` tree → `[Shortcut]` |
| `KeyPeek/MenuReader.swift` | Accessibility calls: permission check, read an app's menu tree |
| `KeyPeek/KeychainStore.swift` | Save, load, delete the API key |
| `KeyPeek/RankingClient.swift` | Build the request, call the API, parse the answer |
| `KeyPeek/RankingStore.swift` | One JSON file per app with its saved ranking |
| `KeyPeek/PanelModel.swift` | State for the panel; ties reader, store and client together |
| `KeyPeek/PanelView.swift` | The SwiftUI panel |
| `KeyPeekTests/*.swift` | One test file per tested type |

## Copy (exact text)

| Situation | Text |
|---|---|
| No Accessibility permission | "KeyPeek needs the Accessibility permission to read the shortcuts of other apps. It only reads menus and changes nothing." Button: "Open System Settings" |
| No shortcuts | "No shortcuts found in this app's menus." |
| Ranking in progress | "Ranking…" |
| No API key | "Add an Anthropic API key from the right-click menu to see the most useful shortcuts." |
| Offline | "No internet connection. Showing all shortcuts." |
| HTTP 401 | "The API key was not accepted. Set it again from the right-click menu." |
| Model declined | "Claude declined to rank this app." |
| Any other failure | "Ranking failed. Try “Re-rank this app” later." |
| Suggestions label | "Suggested by Claude. Not checked, may be wrong." |
| Section titles | "Most useful", "Not in the menus", "All shortcuts" |
| Right-click menu | "Re-rank this app", "Set API key…", separator, "Quit" |

---

### Task 1: Repo, project, and a menu bar icon

**Files:**
- Create: `~/Developer/keypeek/` with `CLAUDE.md`, `.gitignore`, `.claude/settings.json` (copied), `docs/superpowers/specs/…design.md` and `docs/superpowers/plans/…shortcut-viewer.md` (copied)
- Create: `KeyPeek.xcodeproj/project.pbxproj`, `KeyPeek.xcodeproj/xcshareddata/xcschemes/KeyPeek.xcscheme`
- Create: `KeyPeek/main.swift`, `KeyPeek/AppDelegate.swift`, `KeyPeekTests/SmokeTests.swift`

**Interfaces:**
- Produces: `class AppDelegate` with `var statusItem: NSStatusItem!`, `let popover = NSPopover()`, `@objc func iconClicked()`.

- [ ] **Step 1:** `git init` the folder, copy the five files above, commit on `main` as "Add project setup and design documents". Then `git switch -c feature/shortcut-viewer`.
- [ ] **Step 2:** Write the Xcode project with app target `KeyPeek` and hosted test target `KeyPeekTests` (`TEST_HOST = $(BUILT_PRODUCTS_DIR)/KeyPeek.app/Contents/MacOS/KeyPeek`, `BUNDLE_LOADER = $(TEST_HOST)`), and the shared scheme with both Build and Test actions.
- [ ] **Step 3:** `main.swift` as in DockToggle. `AppDelegate`: status item with SF Symbol `keyboard`; left-click toggles the popover (empty 360×480 content for now, `behavior = .transient`); right-click shows a menu with only "Quit" for now. Use DockToggle's `sendAction(on: [.leftMouseUp, .rightMouseUp])` pattern.
- [ ] **Step 4:** `SmokeTests.testAppDelegateExists` asserts `NSApp.delegate is AppDelegate`.
- [ ] **Step 5:** Run build and test commands. Expected: `** BUILD SUCCEEDED **`, `** TEST SUCCEEDED **`. Launch the app; confirm with `pgrep -x KeyPeek`.
- [ ] **Step 6:** Commit "Add KeyPeek app skeleton with menu bar icon".

### Task 2: Shortcut types and key formatting

**Files:**
- Create: `KeyPeek/Shortcut.swift`, `KeyPeek/KeyFormatter.swift`
- Test: `KeyPeekTests/KeyFormatterTests.swift`

**Interfaces:**
- Produces:
  - `struct Shortcut: Equatable, Identifiable { let id: String; let menuPath: [String]; let title: String; let keys: String }` where `id` is `menuPath.joined(separator: " > ") + " > " + title`.
  - `struct Suggestion: Equatable, Codable { let keys: String; let description: String }`
  - `struct MenuNode { let title: String; let cmdChar: String?; let cmdVirtualKey: Int?; let cmdGlyph: Int?; let cmdModifiers: Int; let children: [MenuNode] }`
  - `enum KeyFormatter { static func string(cmdChar: String?, virtualKey: Int?, glyph: Int?, modifiers: Int) -> String? }`

Accessibility modifier bits: `1` = Shift, `2` = Option, `4` = Control, `8` = *no* Command (Command is present unless bit 8 is set). Output order is `⌃⌥⇧⌘` then the key. Letters are shown uppercase. When `cmdChar` is nil or empty, map `glyph`/`virtualKey` to a symbol for at least: Return ↩, Delete ⌫, Forward Delete ⌦, Escape ⎋, Tab ⇥, Space "Space", the four arrows ← → ↑ ↓, Page Up ⇞, Page Down ⇟, Home ↖, End ↘, F1–F12. Return nil when there is no key at all.

- [ ] **Step 1: Failing tests**

```swift
XCTAssertEqual(KeyFormatter.string(cmdChar: "n", virtualKey: nil, glyph: nil, modifiers: 0), "⌘N")
XCTAssertEqual(KeyFormatter.string(cmdChar: ".", virtualKey: nil, glyph: nil, modifiers: 1), "⇧⌘.")
XCTAssertEqual(KeyFormatter.string(cmdChar: "f", virtualKey: nil, glyph: nil, modifiers: 6), "⌃⌥⌘F")
XCTAssertEqual(KeyFormatter.string(cmdChar: "g", virtualKey: nil, glyph: nil, modifiers: 8), "G")
XCTAssertEqual(KeyFormatter.string(cmdChar: nil, virtualKey: 51, glyph: nil, modifiers: 0), "⌘⌫")
XCTAssertEqual(KeyFormatter.string(cmdChar: nil, virtualKey: 126, glyph: nil, modifiers: 2), "⌥⌘↑")
XCTAssertNil(KeyFormatter.string(cmdChar: nil, virtualKey: nil, glyph: nil, modifiers: 0))
XCTAssertNil(KeyFormatter.string(cmdChar: "", virtualKey: nil, glyph: nil, modifiers: 0))
```

- [ ] **Step 2:** Run tests; expect compile failure. **Step 3:** Implement. **Step 4:** Tests pass. **Step 5:** Commit "Add shortcut types and key formatting".

### Task 3: Reading and flattening menus

**Files:**
- Create: `KeyPeek/MenuFlattener.swift`, `KeyPeek/MenuReader.swift`
- Test: `KeyPeekTests/MenuFlattenerTests.swift`

**Interfaces:**
- Consumes: `MenuNode`, `Shortcut`, `KeyFormatter` (Task 2).
- Produces:
  - `enum MenuFlattener { static func shortcuts(from menuBarItems: [MenuNode]) -> [Shortcut] }`
  - `enum MenuReader { static var hasPermission: Bool { get }; static func openPermissionSettings(); static func readMenuBar(pid: pid_t) -> [MenuNode] }`

`MenuFlattener` rules: skip the first menu bar item (the Apple menu); skip any node titled "Services" and everything under it; keep only items for which `KeyFormatter` returns a string and whose title is not empty; `menuPath` is the chain of titles from the top-level menu down to the item's parent; keep menu order; if two items produce the same `id`, keep the first.

`MenuReader.readMenuBar`: `AXUIElementCreateApplication(pid)`, set `AXUIElementSetMessagingTimeout` to 2 seconds, read `kAXMenuBarAttribute`, then walk `kAXChildrenAttribute` recursively (a menu bar item's child is a menu whose children are the items; collapse that so a `MenuNode`'s `children` are its items). Read `kAXTitleAttribute`, `kAXMenuItemCmdCharAttribute`, `kAXMenuItemCmdVirtualKeyAttribute`, `kAXMenuItemCmdGlyphAttribute`, `kAXMenuItemCmdModifiersAttribute`. Any failure returns what was read so far (possibly `[]`). `hasPermission` is `AXIsProcessTrusted()`. `openPermissionSettings` opens `x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility`.

- [ ] **Step 1: Failing tests** in `MenuFlattenerTests`, built from a hand-made tree `[Apple, File, View, Finder-like app menu containing Services]`:
  - `testSkipsAppleMenu`: an item with a shortcut under the first node is absent.
  - `testSkipsServices`: an item with a shortcut under a "Services" submenu is absent.
  - `testDropsItemsWithoutShortcut`.
  - `testNestedPath`: item "Name" under View > Sort By has `menuPath == ["View", "Sort By"]` and `id == "View > Sort By > Name"`.
  - `testKeepsMenuOrder` and `testDuplicateIdKeepsFirst`.
  - `testEmptyInput`: `shortcuts(from: [])` is `[]`.
- [ ] **Step 2:** Fail. **Step 3:** Implement both files. **Step 4:** Tests pass.
- [ ] **Step 5: Manual check.** Add a temporary `print` of `MenuFlattener.shortcuts(from: MenuReader.readMenuBar(pid:))` for Finder at launch, run the app, ask the owner to grant Accessibility when macOS asks, and confirm the output contains `⌘N` "New Finder Window". Note whether `⇧⌘.` appears (expected: it does not). Remove the `print`.
- [ ] **Step 6:** Rebuild once and check whether the permission is still granted. Tell the owner what you saw and, if it was lost, the simplest way to restore it.
- [ ] **Step 7:** Commit "Read and flatten app menus into shortcuts".

### Task 4: Front app tracking and the panel with all shortcuts

**Files:**
- Create: `KeyPeek/FrontAppTracker.swift`, `KeyPeek/PanelModel.swift`, `KeyPeek/PanelView.swift`
- Modify: `KeyPeek/AppDelegate.swift`
- Test: `KeyPeekTests/PanelModelTests.swift`

**Interfaces:**
- Consumes: `MenuReader`, `MenuFlattener`, `Shortcut`.
- Produces:
  - `final class FrontAppTracker { var current: NSRunningApplication? { get } }` — starts with `NSWorkspace.shared.frontmostApplication` and updates on `NSWorkspace.didActivateApplicationNotification`, ignoring KeyPeek itself.
  - `struct MenuGroup: Identifiable { let id: String; let title: String; let shortcuts: [Shortcut] }`
  - `@MainActor final class PanelModel: ObservableObject` with `@Published var appName: String`, `appIcon: NSImage?`, `needsPermission: Bool`, `groups: [MenuGroup]`, and `func open(for app: NSRunningApplication?)`; plus `static func groups(from shortcuts: [Shortcut]) -> [MenuGroup]` (group by `menuPath[0]`, first-seen order).
  - `struct PanelView: View` taking `@ObservedObject var model: PanelModel`.

`open(for:)` sets name and icon immediately, sets `needsPermission` from `MenuReader.hasPermission`, then reads the menus on a background task and publishes `groups` on the main actor. The view shows: header (icon + name); the permission text and button when needed; otherwise a scrolling list with one section per group, each row showing the title (with the submenu path in secondary text when `menuPath.count > 1`) on the left and `keys` on the right in a monospaced font; the "No shortcuts" text when `groups` is empty and reading has finished.

- [ ] **Step 1: Failing tests:** `testGroupsByTopMenuInOrder` (shortcuts from File, Edit, File → two groups "File" with 2, "Edit" with 1, File first) and `testGroupsEmpty`.
- [ ] **Step 2:** Fail. **Step 3:** Implement; `AppDelegate` owns one `FrontAppTracker` and one `PanelModel`, hosts `PanelView` in the popover with `NSHostingController`, and calls `model.open(for: tracker.current)` each time the popover opens. **Step 4:** Tests pass.
- [ ] **Step 5: Manual check.** With Finder in front, click the icon: Finder's name, icon and grouped shortcuts appear. Repeat with Safari and with one app of the owner's choice.
- [ ] **Step 6:** Commit "Show the front app's shortcuts in a panel".

### Task 5: API key in the Keychain

**Files:**
- Create: `KeyPeek/KeychainStore.swift`
- Modify: `KeyPeek/AppDelegate.swift`
- Test: `KeyPeekTests/KeychainStoreTests.swift`

**Interfaces:**
- Produces: `struct KeychainStore { init(service: String = "local.keypeek", account: String = "anthropic-api-key"); func save(_ key: String) -> Bool; func load() -> String?; func delete() }` using generic-password items.

- [ ] **Step 1: Failing test** `testSaveLoadDelete` with `service: "local.keypeek.tests"`: load is nil → save "test-value" → load is "test-value" → save "second" → load is "second" → delete → load is nil. Clean up in `tearDown`.
- [ ] **Step 2:** Fail. **Step 3:** Implement. Add the full right-click menu from the copy table. "Set API key…" shows an `NSAlert` with an `NSSecureTextField`, buttons "Save" and "Cancel"; Save trims whitespace and stores the value, an empty value deletes the stored key. "Re-rank this app" is wired in Task 8.
- [ ] **Step 4:** Tests pass. Run the app and open the dialog; cancel it. Do not enter a real key yourself.
- [ ] **Step 5:** Commit "Store the API key in the Keychain".

### Task 6: Ranking client

**Files:**
- Create: `KeyPeek/RankingClient.swift`
- Test: `KeyPeekTests/RankingClientTests.swift`

**Interfaces:**
- Consumes: `Shortcut`, `Suggestion`.
- Produces:
  - `struct RankingResult: Equatable, Codable { let topIDs: [String]; let suggestions: [Suggestion] }`
  - `enum RankingError: Error, Equatable { case noKey, offline, unauthorized, refused, failed }`
  - `enum RankingClient { static let model = "claude-sonnet-5-5"; static let maxSent = 400; static func requestBody(appName: String, shortcuts: [Shortcut]) throws -> Data; static func parse(_ data: Data, statusCode: Int, shortcuts: [Shortcut]) throws -> RankingResult; static func rank(appName: String, shortcuts: [Shortcut], apiKey: String?) async throws -> RankingResult }`

Request (verify against the `claude-api` skill first): `POST https://api.anthropic.com/v1/messages`, headers `content-type: application/json`, `x-api-key`, `anthropic-version: 2026-10-21`, `anthropic-beta: server-side-fallback-2026-07-01`. Body: `model`, `max_tokens: 8000`, `fallbacks: "default"`, `output_config: { effort: "low", format: { type: "json_schema", schema: … } }`, one user message. No `thinking`, `temperature` or `tool_choice` fields. Schema: object with `top` (array of integers) and `extra` (array of objects with string `keys` and string `description`), both required, `additionalProperties: false` on every object.

The user message lists the app name and the first `maxSent` shortcuts, one per line as `<index>. <menu path> > <title> — <keys>`, and asks for: `top` = the indices of the up to 10 shortcuts most worth knowing for everyday use, best first; `extra` = up to 8 well-known keyboard shortcuts of this app that are not in the list, with `keys` written in the same symbol style, and an empty array if unsure rather than a guess. The builder writes the exact wording.

`parse`: status 401 → `.unauthorized`; any other non-200 → `.failed`; `stop_reason == "refusal"` → `.refused`; any other stop reason than `end_turn` → `.failed`; then decode the first `text` content block as the schema. Map `top` indices to shortcut ids, dropping out-of-range and repeated indices, keeping at most 10. From `extra`, drop entries whose `keys` equal the `keys` of any menu shortcut and entries with empty `keys` or `description`, keeping at most 8. `rank`: nil or empty key → `.noKey`; `URLError` → `.offline`; 30 second timeout.

- [ ] **Step 1: Failing tests** (fixture JSON strings in the test file):
  - `testRequestBodyHasModelAndSchema`: decoded body has `model == "claude-sonnet-5-5"`, `output_config.format.type == "json_schema"`, and the message text contains `"0. File > New Window — ⌘N"`.
  - `testRequestBodyCapsAt400`: with 450 shortcuts the text contains `"399. "` and not `"400. "`.
  - `testParseValid`: `top: [2,0]`, one extra → `topIDs` are the ids of shortcuts 2 and 0, one suggestion.
  - `testParseDropsBadIndices`: `top: [0,0,99,-1,1]` → ids of 0 and 1.
  - `testParseCapsAtTenAndEight`.
  - `testParseDropsSuggestionDuplicatingMenuKeys`: extra with `keys == "⌘N"` is dropped when a menu shortcut has `⌘N`.
  - `testParse401`, `testParse500`, `testParseRefusal`, `testParseMaxTokens`, `testParseGarbage` → the errors above.
  - `testRankWithoutKey`: `rank(..., apiKey: nil)` throws `.noKey` without touching the network.
- [ ] **Step 2:** Fail. **Step 3:** Implement. **Step 4:** Tests pass (none of them calls the real API).
- [ ] **Step 5:** Commit "Add Claude ranking client".

### Task 7: Saved rankings

**Files:**
- Create: `KeyPeek/RankingStore.swift`
- Test: `KeyPeekTests/RankingStoreTests.swift`

**Interfaces:**
- Consumes: `RankingResult`.
- Produces: `struct RankingStore { init(directory: URL = <Application Support>/KeyPeek/rankings); func load(bundleID: String) -> RankingResult?; func save(_ result: RankingResult, bundleID: String); func delete(bundleID: String) }`. File name is the bundle ID with every character outside `A-Z a-z 0-9 . -` replaced by `_`, plus `.json`. The directory is created on first save.

- [ ] **Step 1: Failing tests** against a temporary directory: `testRoundTrip`, `testMissingIsNil`, `testCorruptFileIsNil` (write "not json" to the file, expect nil), `testDeleteRemoves`, `testOddBundleIDIsSafeFileName` (`"a/b:c"` saves and loads, and no file is created outside the directory).
- [ ] **Step 2:** Fail. **Step 3:** Implement. **Step 4:** Pass. **Step 5:** Commit "Save rankings per app".

### Task 8: Ranked sections, re-rank, and finish

**Files:**
- Modify: `KeyPeek/PanelModel.swift`, `KeyPeek/PanelView.swift`, `KeyPeek/AppDelegate.swift`
- Test: `KeyPeekTests/PanelModelTests.swift`

**Interfaces:**
- Consumes: `RankingClient.rank`, `RankingStore`, `KeychainStore`, `RankingError`.
- Produces on `PanelModel`:
  - `enum RankingState: Equatable { case idle, ranking, ready, message(String) }`
  - `@Published var top: [Shortcut]`, `suggestions: [Suggestion]`, `rankingState: RankingState`
  - `func rerank()`
  - `init(store: RankingStore, loadKey: @escaping () -> String?, rank: @escaping (String, [Shortcut], String?) async throws -> RankingResult)` so tests can inject fakes; the app passes the real ones.
  - `static func message(for error: RankingError) -> String` returning the copy-table text.
  - `static func resolve(_ result: RankingResult, in shortcuts: [Shortcut]) -> [Shortcut]` (ids no longer present are left out, order kept).

Flow after the menus are read for an app with a bundle ID: saved result → show it, state `.ready`. Otherwise state `.ranking`, call `rank`; on success save under that bundle ID and, only if the panel is still showing that same bundle ID, publish and set `.ready`; on error set `.message(...)`. No shortcuts or no bundle ID → no request, state `.idle`. `rerank()` deletes the saved result for the current app and runs the flow again. The view adds "Most useful" above everything (rows, or the "Ranking…"/message line), then "Not in the menus" with the suggestions label when there are suggestions, then "All shortcuts".

- [ ] **Step 1: Failing tests:**
  - `testResolveDropsMissingIDs`.
  - `testMessageForEachError`: exact strings from the copy table.
  - `testUsesSavedRankingWithoutCallingRank`: fake `rank` records calls; with a saved result, call count is 0 and state is `.ready`.
  - `testRanksAndSavesOnFirstOpen`: call count 1, store now has the result.
  - `testErrorShowsMessageAndKeepsGroups`: fake throws `.offline` → state is `.message("No internet connection. Showing all shortcuts.")` and `groups` is not empty.
  - `testLateResultForOtherAppIsNotShown`: start ranking for bundle A with a fake that suspends, switch the model to bundle B, let A finish → `top` is empty for B, and the store has A's result under A.
  - `testNoShortcutsMakesNoRequest`.

  To make these testable without the Accessibility API, give `PanelModel` an internal `func show(appName: String, bundleID: String?, shortcuts: [Shortcut]) async` that `open(for:)` calls after reading menus; tests call `show` directly.
- [ ] **Step 2:** Fail. **Step 3:** Implement and wire "Re-rank this app". **Step 4:** All tests pass.
- [ ] **Step 5: Manual checks with the owner.** Without a key: Finder panel shows all shortcuts plus the no-key line. The owner sets their key through "Set API key…". Open over Finder: "Most useful" fills in; confirm `⇧⌘.` appears in the menus list or under "Not in the menus" (if it appears in neither, report that plainly; do not hard-code it). Close and reopen: instant, no "Ranking…". Turn Wi-Fi off, "Re-rank this app": offline line, full list intact. Wi-Fi back on.
- [ ] **Step 6:** `git grep -n -i "sk-ant"` returns nothing; `git status` is clean apart from intended files.
- [ ] **Step 7:** Commit "Show ranked and suggested shortcuts". Switch to `main`, `git merge --no-ff feature/shortcut-viewer`, delete the branch, show `git log --oneline --graph`. Leave the app running and tell the owner how to test it and what was not verified.
