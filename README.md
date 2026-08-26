# mac-explorer

A native macOS file manager built in SwiftUI, modelled closely on the Windows 10
era File Explorer — ribbon, breadcrumb address bar, navigation tree, eight view
layouts, details pane and status bar.

<!-- Screenshot goes here once you've built and run it. -->

## Building

Requires macOS 13 or later and Xcode 15 (or a Swift 5.9 toolchain).

```sh
./Scripts/build-app.sh          # debug build → build/MacExplorer.app
./Scripts/build-app.sh release  # optimized build
open build/MacExplorer.app
```

The script compiles the SwiftPM executable, wraps it in an app bundle with
`Resources/Info.plist`, and ad-hoc signs it. The bundle matters: macOS grants
Desktop/Documents/Downloads access to bundles, not to loose binaries, so
running `.build/debug/MacExplorer` directly will hit permission errors on
protected folders.

You can also open `Package.swift` in Xcode and run the `MacExplorer` scheme.

The first time you browse into Desktop, Documents or Downloads, macOS will
prompt for access — that is TCC, not the app. Grant it once per folder.

## What's implemented

**Chrome**

- **Ribbon** with File, Home, Share and View tabs, collapsible via the chevron
  at its right edge or by clicking the active tab. Groups are separated by
  rules and captioned, with tall and short command buttons as in Explorer.
- **Address bar** with Back / Forward / Recent locations / Up, breadcrumb
  segments whose chevrons drop down that folder's subfolders, a refresh button,
  and click-the-empty-space-to-edit-the-path behaviour.
- **Navigation pane** with Quick access (pinnable), This Mac and Network
  sections, expandable folder trees, and per-row context menus.
- **Status bar** with item and selection counts, selected size, and the two
  quick layout toggles at the right.
- **Details pane** and **Preview pane** (Quick Look backed), mutually exclusive
  like Explorer's, both toggled from the View tab.

**Views**

All eight Explorer layouts: extra large / large / medium / small icons, list,
details, tiles and content. Details view has sortable, drag-resizable columns
(Name, Date modified, Type, Size) and "size all columns to fit".

Grouping by name, date modified, type or size, using Explorer's own buckets —
`Tiny (0 - 10 KB)`, `Earlier this week`, `0 - 9`, and so on — with collapsible
group headers.

**Operations**

New folder and new file, rename in place (F2), delete to Trash (Shift for
permanent), cut / copy / paste, paste shortcut (creates a symlink), duplicate,
copy path, compress to zip via `ditto`, move to / copy to, share sheet, email,
open with, reveal in Finder, open Terminal here, and a properties sheet that
sums folder sizes off the main thread.

Search is recursive from the current folder, runs off the main thread, streams
results in as they're found, and cancels when you navigate away or type again.

Drag and drop moves within a volume and copies across volumes, matching
Explorer's same-drive/different-drive rule. Dragging items out to Finder or
another app works too.

The current folder is watched, so changes made by other apps show up without a
manual refresh.

**Keyboard**

| Key | Action |
| --- | --- |
| `↑` `↓` `PgUp` `PgDn` `Home` `End` | Move selection (hold `⇧` to extend) |
| `⏎` | Open selection |
| `F2` | Rename |
| `⌫` | Move to Trash (`⇧⌫` deletes permanently) |
| `⎋` | Cancel rename, clear search, or deselect |
| `⌘↑` | Up one level |
| `⌘[` / `⌘]` | Back / Forward |
| `⌘1`…`⌘8` | Switch layout |
| `⌘⇧.` | Toggle hidden items |
| `⌘⇧N` | New folder |
| `⌘R` | Refresh |
| `⌘I` | Properties |
| letters | Type-ahead select |

View options and Quick access pins persist in `UserDefaults`.

## Deliberate departures from Windows

- **Delete** uses the Trash rather than a Recycle Bin, and the Recycle Bin is
  not a browsable location.
- **This PC** is **This Mac**, listing the standard home folders and mounted
  volumes; there are no drive letters.
- **Paste shortcut** creates a POSIX symlink, since `.lnk` files mean nothing
  here.
- The Share tab drops **Burn to disc**, **Fax** and **Print**, which have no
  sensible macOS equivalent, and adds Reveal in Finder / Open Terminal here.
- Chrome is fixed to the Windows 10 light palette rather than following the
  system appearance, which is the point of the exercise.

## Layout

```
Sources/MacExplorer/
  MacExplorerApp.swift       app entry, window group, menu commands
  Support/                   Win10 palette + metrics, formatters, icon cache
  Models/                    FileItem, view options, sidebar roots
  Services/                  directory reads, sorting/grouping/search,
                             file operations, clipboard, folder watcher
  ViewModels/                ExplorerViewModel — all navigation and command state
  Views/
    ExplorerWindow.swift     pane assembly and splitters
    ExplorerKeyboard.swift   window-scoped key handling
    AddressBar.swift  NavigationPane.swift  StatusBarView.swift
    Ribbon/                  tab strip, control vocabulary, three tab bodies
    Content/                 the eight layouts and shared item chrome
    Panes/                   preview, details, properties
```

## Known gaps

- No rubber-band (marquee) selection in the icon layouts yet.
- Left/right arrows move by one item rather than by grid column.
- Column choice is fixed to the four defaults; Explorer's "Add columns" isn't
  implemented.
- No tabs (Windows 11's addition, and out of scope for a Windows 10 look).
- There's no test target — everything currently lives in one executable target.
  Splitting the models and services into a `MacExplorerCore` library would make
  the sorting, grouping and size-formatting logic directly testable.
