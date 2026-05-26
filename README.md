# Copy & Paste

A lightweight native macOS clipboard manager that lives exclusively in the menu bar — no Dock icon, no bloat.

Inspired by [paste-hist](https://github.com/massimiliano-volpiana/paste-hist) by Massimiliano Volpiana.

---

## Features

### Clipboard History
- Captures **text**, **links**, **emails**, and **images** automatically
- Up to 500 items (configurable), persisted across sessions
- **Pin** important items so they're never trimmed
- Search across all items in real time
- Filter by type: All · Links · Emails · Images
- Keyboard-driven: `↑↓` navigate, `↩` paste, `⌘⌫` delete

### Image Preview
- Image items display a **96×60 thumbnail** inline
- Hover the thumbnail to reveal a full **popover preview** with pixel dimensions
- Screenshot dimensions shown directly in the row (`1920 × 1080`)

### Screenshot Folder Monitor
- Point the app at any folder (e.g. `~/Desktop` or a custom Screenshots path)
- Every new image file dropped in that folder is **automatically ingested** into history
- Supports PNG, JPG, JPEG, TIFF, HEIC, GIF, BMP, WebP

### Three Configurable Shortcuts
| Action | Default | Description |
|--------|---------|-------------|
| **Open panel** | `⌘⇧V` | Show the clipboard history panel at cursor |
| **Quick paste text** | `⌘⇧X` | Instantly paste last text item, no panel |
| **Quick paste image** | `⌘⇧Z` | Instantly paste last image item, no panel |

All shortcuts are recorded in-app — click the field and press the new combo.
Supports Cmd, Shift, Option, Control, and the Fn modifier (where the keyboard
sends it as `kCGEventFlagMaskSecondaryFn`).

### Menu Bar Only
- No Dock icon, no main window
- Always accessible via the `⊞` icon in the menu bar or your hotkey
- Runs as a background accessory process

---

## Requirements

- macOS 13 Ventura or later
- Swift 5.9+ (only needed for building from source)
- **Accessibility permission** — required for auto-paste via `⌘V` simulation
- **Input Monitoring permission** — required for global hotkey detection
  (CGEventTap engine, intercepts before macOS dead-key composition)

On first launch, the app requests both permissions. Grant them via
**System Settings → Privacy & Security**, then restart the app.

> **Tip:** if hotkeys stop working after rebuilding from source, reset and
> re-grant via `tccutil reset ListenEvent it.tmi.copypaste` then toggle the
> entry in Input Monitoring. Ad-hoc signed binaries get a new code hash on
> every rebuild, which invalidates the TCC permission record.

---

## Installation

### Option 1 — Build from source

```bash
git clone https://github.com/lucabartolinitmi/copy-paste.git
cd copy-paste
make install   # builds release binary, creates .app, copies to /Applications
```

Then launch from `/Applications/CopyPaste.app`.

### Option 2 — Run without installing

```bash
make run       # builds and opens CopyPaste.app in the project folder
```

---

## Building

```bash
# Debug build
swift build

# Release build + .app bundle (in project folder)
make bundle

# Release build + install to /Applications
make install

# Clean
make clean
```

---

## Usage

1. **Launch** the app — a clipboard icon appears in your menu bar
2. **Grant Accessibility access** when prompted (required for auto-paste)
3. **Copy anything** — text, images, links are captured automatically
4. **Open the panel** with `⌘⇧V` (or click the menu bar icon)
5. **Navigate** with `↑↓`, **paste** with `↩`, **search** by typing
6. **Configure** shortcuts and screenshot folder via the gear icon in the panel

### Keyboard Shortcuts (panel)

| Key | Action |
|-----|--------|
| `↑` / `↓` | Navigate items |
| `↩` | Paste selected item |
| `⌘⌫` | Delete selected item |
| `⌘⇧⌫` | Clear all (unpinned) |
| `Esc` | Close panel |

---

## Settings

Open via the gear icon in the panel or **menu bar → Settings…**

| Tab | Options |
|-----|---------|
| **General** | Launch at login · Capture images · Persist history · Max items |
| **Shortcuts** | Record hotkeys for Open panel / Quick paste text / Quick paste image |
| **Screenshots** | Enable folder watch · Choose folder path |

---

## Project Structure

```
Sources/CopyPaste/
├── main.swift                  — entry point, menu-bar activation
├── AppDelegate.swift           — status item, lifecycle, quick-paste handlers
├── AppSettings.swift           — UserDefaults persistence, 3 hotkeys, folder path
├── ClipboardItem.swift         — data model (text/image, type detection)
├── ClipboardStore.swift        — observable store, add/pin/delete/trim
├── ClipboardMonitor.swift      — NSPasteboard polling (0.5s interval)
├── ScreenshotFolderMonitor.swift — kqueue DispatchSource folder watcher
├── HotkeyManager.swift         — Carbon EventHotKey registration (3 hotkeys)
├── NavigationState.swift       — shared UI state (selection, search, filter)
├── PopupWindowController.swift — floating NSPanel, keyboard handling, paste sim
├── ClipboardListView.swift     — SwiftUI list with image thumbnails + popover
├── SettingsView.swift          — 3-tab settings UI with hotkey recorder
└── PasteLog.swift              — optional file logger (/tmp/copypaste.log)
```

---

## License

MIT — see [LICENSE](LICENSE)
