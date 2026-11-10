# KeyPeek

A small macOS menu bar app that shows the keyboard shortcuts of the app you are using, with the most useful ones at the top.

Click the ⌘ icon in the menu bar and KeyPeek opens a panel for the app in front:

- **My shortcuts**: shortcuts you added yourself for this app.
- **Most useful**: up to 10 shortcuts from the app's menus, ranked by Claude Sonnet.
- **Not in the menus**: well-known shortcuts the app does not list in its menus, suggested by Claude. These are not checked and may be wrong.
- **All shortcuts**: every shortcut found in the app's menus, grouped by menu.

KeyPeek was built as a learning project. It is version 1 and has only been built and tested on macOS 27 with Xcode 27.

## Requirements

- A Mac running macOS 14 or later (tested on macOS 27 only)
- Xcode (tested with Xcode 27)
- Optional: an Anthropic API key, for the "Most useful" and "Not in the menus" sections. Without a key, KeyPeek still lists all shortcuts.

## Setup

### 1. Build and run

Download or clone this repository, then either:

- open `KeyPeek.xcodeproj` in Xcode and press **Run**, or
- build from the command line:

```bash
xcodebuild -project KeyPeek.xcodeproj -scheme KeyPeek -derivedDataPath build build
open build/Build/Products/Debug/KeyPeek.app
```

KeyPeek has no window and no Dock icon. Look for the ⌘ symbol in a circle in the menu bar.

### 2. Allow KeyPeek to read menus

KeyPeek reads other apps' menus through the macOS Accessibility permission. It only reads; it never clicks or changes anything.

1. Left-click the KeyPeek icon. The panel explains the permission.
2. Click **Open System Settings**.
3. Switch **KeyPeek** on under Privacy & Security > Accessibility.
4. Left-click the icon again.

### 3. Add an API key (optional)

1. Create an API key in the [Anthropic Console](https://console.anthropic.com/). API usage is billed separately from a Claude subscription.
2. Right-click the KeyPeek icon and choose **Set API key…**.
3. Paste the key and click **Save**.

The key is stored in the macOS Keychain, never in a file. To remove it, open the same dialog, leave the field empty and click Save.

Ranking costs a few cents per app and happens once per app; the result is saved and reused.

## Using it

- **Left-click** the icon: show the shortcuts of the app in front.
- **Right-click** the icon:
  - **Add my shortcut…**: press a key combination and describe it. It is saved for the app in front and shown at the top of the panel. Use this for shortcuts that neither the menus nor Claude know.
  - **Re-rank this app**: discard the saved ranking of the app shown last and ask Claude again.
  - **Set API key…**
  - **Quit**

## Privacy

- With an API key set, KeyPeek sends the app's name and its list of menu shortcuts (menu path, item title, key combination) to Anthropic, once per app. Nothing else is sent.
- Menu items that have a shortcut and a personal title, such as browser favourites or mailbox names, are part of that list.
- The Services submenu is left out, because it can contain names you made up.
- Shortcuts you add yourself stay on your Mac and are never sent.
- Without an API key, KeyPeek makes no network requests.

## Where KeyPeek keeps its data

| What | Where |
|---|---|
| API key | macOS Keychain, entry `local.keypeek` |
| Saved rankings | `~/Library/Application Support/KeyPeek/rankings/` |
| Your own shortcuts | `~/Library/Application Support/KeyPeek/my-shortcuts/` |

## Troubleshooting

**The panel asks for the Accessibility permission again after I rebuilt the app.**
The app is signed for local use only, so macOS treats every new build as a different app. Reset the entry, then grant it again as in step 2:

```bash
tccutil reset Accessibility local.keypeek
```

**macOS asks for my login password when KeyPeek starts ranking.**
After a rebuild, the Keychain asks before it hands the stored key to the new build. Choose "Always Allow".

**"No shortcuts found in this app's menus."**
Some apps expose few or no shortcuts through their menus. You can still add your own.

**A shortcut I know is missing.**
KeyPeek can only read shortcuts that appear in the app's menus. Add it with "Add my shortcut…".

## Known limits

- Menus are read in your Mac's language, so titles are not translated.
- Suggested shortcuts under "Not in the menus" are not verified.
- If an app takes longer than 5 seconds to answer, its list may be cut short.
- A request that times out is reported as "No internet connection".
- "Re-rank this app" discards the old ranking before the new one arrives.
- The Globe/Fn key is not shown in key combinations.

## Removing KeyPeek

Quit KeyPeek from its right-click menu, delete the app and the `~/Library/Application Support/KeyPeek` folder, remove the stored key with "Set API key…" before quitting (or delete the `local.keypeek` entry in Keychain Access), and run the `tccutil` command above.

## For developers

- Swift, AppKit for the menu bar icon, SwiftUI for the panel. No third-party libraries.
- Run the tests (they need no API key and no network):

```bash
xcodebuild -project KeyPeek.xcodeproj -scheme KeyPeek -derivedDataPath build test
```

- The design and the original build plan are in `docs/superpowers/`.
- The Claude model is set in one place, `RankingClient.model` in `KeyPeek/RankingClient.swift`.
