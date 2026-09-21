# Softplan

A planner for macOS that puts everything on one horizontal timeline. Zoom out to
twelve years to see the shape of the next few years, or in to a single week to
see the shape of your fortnight. Plans are bars you drag, stretch and stack —
there are no lists, no columns and no accounts.

Everything lives in a SQLite file on your Mac. Softplan has no network code at
all: nothing is uploaded, synced or reported.

## Install

Download `Softplan-X.Y.Z.zip` from the
[latest release](https://github.com/Rishabh-codes-star/Softplan/releases/latest),
unzip it, and move `Softplan.app` into your Applications folder.

The first launch needs one extra step. Softplan is ad-hoc signed rather than
notarized with a paid Apple Developer ID, so macOS blocks it the first time.
Try to open it once, then go to **System Settings → Privacy & Security** and
click **Open Anyway**. (On macOS 14, right-clicking the app and choosing
**Open** also works; macOS 15 removed that shortcut.) From the terminal,
`xattr -d com.apple.quarantine /Applications/Softplan.app` does the same.

Your plans live outside the app, so replacing it with a newer release keeps
every one of them. Each release lists what changed in its notes and in
[CHANGELOG.md](CHANGELOG.md).

### Build it yourself

```bash
./scripts/make-app.sh release
```

That builds the app, wraps it in a proper bundle, and installs it to
`~/Applications/Softplan.app` — no Gatekeeper step, since a build you compiled
yourself is never quarantined. Quit Softplan before rebuilding: the script
replaces the bundle in place, and a running copy keeps the old code until it is
relaunched.

### Requirements

- macOS 14 or later
- A Swift 6 toolchain (the Xcode Command Line Tools are enough to build)
- Xcode, optionally — `make-app.sh` uses its `actool` to compile the asset
  catalog into a modern Dock icon, and falls back to `App/AppIcon.icns` when
  Xcode is absent. Running the tests needs Xcode, which is where `XCTest` lives.

## Development

```bash
swift build            # compile
swift run              # launch straight from the build directory
swift test             # run the test suite
```

If Xcode is installed but not selected (`xcode-select -p` points at the Command
Line Tools), `swift test` cannot find `XCTest`. Reach the Xcode toolchain for a
single command instead of changing your global setup:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test
```

## Using it

| Shortcut | Does |
| --- | --- |
| `⌘N` | New plan, starting at the middle of the visible range |
| `⌘T` | Jump to today |
| `⌘+` / `⌘-` | Zoom in / out |
| `⌘R` | Reload plans from disk |
| `Return` / `Esc` | Save / dismiss in the editor |

On the canvas:

- **Drag empty space** to sketch a plan across the days you drag over, or
  **double-click** for a month-long one.
- **Two-finger scroll** moves through rows; **scroll sideways** (or hold
  `Shift`) travels through time.
- **Pinch**, or hold `⌘` while scrolling, to zoom around the pointer.
- **Drag a bar** to move it, or drag the soft pills at either end to change its
  start or finish. Both snap to whole days.
- **Click a wide bar** that has a description to expand it; click any other bar
  to open the editor. **Right-click** for edit and delete.

Dates are day-level throughout — a plan is a range of whole days, never a time
of day.

## Your data

```
~/Library/Application Support/Softplan/softplan.sqlite
```

One `events` table, readable with any SQLite client, created `0600` so only your
account can read it. Copy that file to back up every plan you have; delete it
and Softplan starts empty. Databases written by older versions are migrated on
open, so an upgrade never loses columns.

Where the timeline sits — the zoom level and the leftmost visible day — is
remembered in `UserDefaults` under `viewport.ppd` and `viewport.leftDay`. Window
size and position are macOS's own window restoration, not Softplan's.

## Layout

```
Sources/Softplan/
  SoftplanApp.swift        app entry, window, menu commands
  Models/PlanEvent.swift   one plan: a title, a day range, a colour, details
  Persistence/Database.swift   SQLite wrapper — schema, migration, CRUD
  State/AppModel.swift     the observable store the views share
  Support/DayMath.swift    day-index arithmetic (day 0 = 2000-01-01)
  Support/Palette.swift    colour families and shared layout constants
  Timeline/                the canvas: viewport, grid, stacking, bars
  UI/                      the editor sheet and its calendar
Tests/SoftplanTests/       date maths, stacking, palette, database
App/                       Info.plist and the fallback .icns
Assets/                    source artwork for the icon and the header mark
scripts/make-app.sh        build + bundle + install
scripts/release.sh         version bump, tag and GitHub Release
scripts/make-icon.swift    regenerate icon sizes from Assets/App_logo.png
AGENTS.md                  project context for AI coding assistants
```

The timeline works in **day indices** — whole days counted from 2000-01-01 —
rather than `Date`s. `Viewport` turns those into pixels through two numbers,
`pixelsPerDay` and `leftDay`, and everything drawn on the canvas follows from
that pair.

### Cutting a release

Versions follow [Semantic Versioning](https://semver.org): `1.0.1` for fixes,
`1.1.0` for new features, `2.0.0` for changes people have to adapt to.

1. Add a `## [X.Y.Z] - YYYY-MM-DD` section to [CHANGELOG.md](CHANGELOG.md) and
   commit it. That text becomes the release notes.
2. Run `./scripts/release.sh X.Y.Z`.

The script bumps the version in `App/Info.plist`, runs the tests, builds and
zips the app with a SHA-256 checksum, tags `vX.Y.Z`, pushes, and publishes the
GitHub Release. Publishing needs the GitHub CLI signed in
(`brew install gh && gh auth login`); without it the script stops after pushing
the tag and prints the one manual step left.

### Regenerating the icon

```bash
swift scripts/make-icon.swift
cp scripts/AppIcon.iconset/*.png Assets.xcassets/AppIcon.appiconset/
iconutil -c icns scripts/AppIcon.iconset -o App/AppIcon.icns
```

Both destinations matter: `make-app.sh` compiles the asset catalog when Xcode is
present and uses the `.icns` when it is not.

## Accessibility

Every plan bar is a single VoiceOver element that reads its title, dates and
length, and carries Edit and Delete as actions — the mouse-only paths to both.
Controls are labelled rather than announced by symbol name, selected state is
exposed on colour swatches and calendar days, gridlines and other decoration are
hidden from assistive technology, and plans can be created and reached from the
keyboard alone. Softplan honours the system's Reduce Motion setting when moving
the timeline.

## License

MIT — see [LICENSE](LICENSE).
