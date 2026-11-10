# Shortcut viewer (working name: KeyPeek) — design

Date: 2026-11-10
Status: approved by the owner on 2026-11-10

Lines marked **(Claude's call)** are defaults Claude chose; the owner has not
discussed them and can change any of them. Everything else is what the owner said.

## Intent and why

The owner keeps forgetting keyboard shortcuts (their example: `Cmd+Shift+.` to show
hidden files in Finder). They want one button in the menu bar that shows every
keyboard shortcut of the app they are currently using, with the most useful ones
at the top so they don't have to scan a long list.

"Most useful" is decided by an AI model. The owner chose Claude Sonnet over a local
model: best ranking first, cost is negligible.

The owner is a beginner learning Swift, Xcode and Git through these projects. The
code must stay simple enough for them to read.

## Decision: shortcuts that are not in the menus

The owner's own example, `⇧⌘.` in Finder, is very likely not in Finder's menus
(not confirmed on this Mac; the builder should confirm once the app has the
Accessibility permission). The owner decided on 2026-11-10 that the app should
also show well-known shortcuts that are not in an app's menus, suggested by
Claude, in their own clearly labelled section.

## Goals (version 1)

1. A menu bar icon. Clicking it opens a small panel for the app that was in
   front when they clicked.
2. The panel lists that app's keyboard shortcuts, read live from its menus.
3. A "Most useful" section at the top, ranked by Claude Sonnet.
4. Below it, all shortcuts grouped by menu (File, Edit, View, ...).
5. A "Not in the menus" section: well-known shortcuts of that app that its
   menus don't list, suggested by Claude Sonnet and labelled as suggestions.
6. The ranking and the suggestions for an app are fetched once and saved, so
   later opens are instant and cost nothing.

## Non-goals (later, not now)

- Adapting to the owner's own usage (remembering or pinning what they look up)
- A local model (Ollama) as an alternative to Claude
- A global keyboard shortcut to open the panel
- Search inside the panel
- Launch at login, app icon
- System-wide shortcuts that don't belong to the app in front
- Checking whether a suggested shortcut really works

## Anti-goals (would make it a failure even if it works)

- The API key ending up in Git, in a source file, or in a plain text file
- Sending anything to Anthropic other than the app's name and its shortcut
  list (menu path, item title, key combination)
- The panel waiting on the network: the full list must appear immediately,
  and the ranked section fills in when it arrives
- A suggested shortcut shown as if it were a confirmed one: suggestions must
  always be visibly separate from shortcuts read from the menus
- Code a beginner can't follow

## How it behaves

**Opening.** Left-click on the menu bar icon opens the panel; clicking
elsewhere closes it. Right-click opens a small menu: "Re-rank this app",
"Set API key…", "Quit". **(Claude's call)**

**Which app.** The panel shows the app that was frontmost just before the
click. The app is menu-bar-only (no Dock icon), like DockToggle.

**The panel.** **(Claude's call on layout)**
- Header: the app's icon and name.
- "Most useful": up to 10 shortcuts, each with the key combination and the
  menu item's title.
- "Not in the menus": up to 8 suggested shortcuts, with a short line saying
  they were suggested by Claude and may be wrong. Suggestions that duplicate
  a key combination already found in the menus are dropped.
- "All shortcuts": every shortcut, grouped under its top-level menu name, in
  menu order. Scrollable.
- Key combinations are drawn with the usual symbols (⌘ ⇧ ⌥ ⌃).

**First open for an app.** The full list shows at once. "Most useful" shows
"Ranking…" while the request runs, then fills in together with "Not in the
menus". The result is saved per app.

**Later opens.** The saved ranking is used. If a saved shortcut no longer
exists in the app's menus, it is left out. **(Claude's call)**

**When ranking can't happen** (no API key yet, offline, error, or the model
declines): the full list still works; the "Most useful" section shows one
plain line saying why and what to do.

**Permission.** Reading another app's menus needs the Accessibility
permission. On first launch without it, the panel explains this in one or two
sentences and offers a button that opens the right page in System Settings.

## Constraints

- macOS 27 (Golden Gate), Xcode 27.2, Apple M3. Swift + AppKit, NSStatusItem.
  No third-party libraries.
- Everything local: its own new folder and Git repo, no remotes, no pushing.
  **(Claude's call: `~/Developer/keypeek`)**
- Follows the owner's standing rules (copy `CLAUDE.md` from `~/Developer/dock`):
  explain each step in plain language, keep code simple, feature branch then
  local merge, build and run before saying it's done, explain each commit,
  branch and merge in one sentence.
- Openable in Xcode with Run, and buildable with `xcodebuild`, set up the
  same way as `~/Developer/dock/DockToggle.xcodeproj`.
- App Sandbox off (the Accessibility API needs it off). Signed to run locally.

## How it gets made

**Reading shortcuts.** Use the macOS Accessibility API: get the frontmost
app's menu bar, walk every menu and submenu, and keep each item that has a
key combination. Skip the Apple menu and the Services submenu (Services can
carry user-defined, personal names). **(Claude's call)** Only items with a
shortcut are kept, which also keeps document names and recent files out of
the list.

**Ranking.** One request to the Claude API per app.
- Model: Claude Sonnet (the owner's choice). The current model ID is
  `claude-sonnet-5-5`, confirmed against the `claude-api` skill on 2026-11-10.
  Keep the ID in one constant so it is easy to change.
- Swift has no official Anthropic SDK, so this is a plain HTTPS request with
  `URLSession`.
- Input: app name plus the shortcut list. Output, as structured data: (1) an
  ordered list of up to 10 of those shortcuts, which the app matches back to
  its list, and (2) up to 8 well-known shortcuts of that app that are not in
  the list, each with a key combination and a short description. The prompt
  should tell the model to leave (2) empty rather than guess.
- The builder must load the `claude-api` skill before writing this code and
  follow it for request shape, structured output and refusal handling; do not
  write the request from memory.

**API key.** the owner creates a key in the Anthropic Console themselves and types it
into the app ("Set API key…"). The app stores it in the macOS Keychain. Claude
never handles the key. API usage is billed separately from a Claude
subscription; expected cost is a few cents per app, once.

**Saved rankings.** One small JSON file per app (named by the app's bundle
identifier) in the app's Application Support folder. **(Claude's call)**

**Suggested code layout** (builder may adjust): the menu bar icon and panel;
the shortcut reader; the ranking client; the saved-rankings store; the
Keychain helper. Each in its own small file, as DockToggle did.

## Known risks

- **Permission resets while developing.** With local signing, macOS can treat
  each rebuild as a new app and ask for the Accessibility permission again.
  The builder should confirm whether this happens and, if so, tell the owner the
  simplest way to live with it.
- **Apps with unusual menus.** Some apps (Electron apps, games) expose few or
  no shortcuts through their menus. The panel then shows what it finds, or
  "No shortcuts found in this app's menus".
- **Ranking quality for niche apps.** The model may know them less well. The
  full list is always there as the fallback.

## Left to the builder

- Exact panel type and sizes, fonts, the menu bar icon symbol
- The prompt wording for the ranking
- How to detect "the app that was in front before the click"
- Error wording
- Which parts get automated tests (the menu-walking output and the matching
  of ranked results back to the list are good candidates)

## Done means

- The app builds from Xcode and from the command line and runs in the menu bar.
- With permission granted, opening it over Finder lists the shortcuts in
  Finder's menus (for example `⌘N` New Finder Window).
- With an API key set, `⇧⌘.` (show hidden files) appears for Finder, either
  from the menus or under "Not in the menus".
- With an API key set, "Most useful" and "Not in the menus" fill in for a
  first-time app and are instant the second time.
- Without a key or network, the full list still works and the panel says why
  there is no ranking.
- No key or secret appears anywhere in the repo.
- Work is committed on a feature branch and merged into main locally.
