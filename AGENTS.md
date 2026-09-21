# AGENTS.md

Context for AI coding assistants (Claude Code, Codex, ChatGPT, Cursor and
others) working on Softplan. `CLAUDE.md` imports this file, so this is the one
place to keep project context up to date. When a decision changes, change it
here.

## What Softplan is

A macOS planner that puts every plan on one horizontal timeline, zoomable from
about twelve years down to a single week. Plans are bars you draw, drag,
stretch and colour. It is deliberately one timeline — no boards, lanes, lists
or accounts — and deliberately local: plans live in a SQLite file on the Mac
and the app has no network code.

It is open source under MIT and distributed as zipped app builds on GitHub
Releases.

## Stack and constraints

- SwiftUI + AppKit, macOS 14 minimum, built as a **Swift Package** executable.
  There is no Xcode project; Xcode can open `Package.swift` directly.
- **No third-party dependencies.** Persistence is the system `SQLite3` module.
  Adding a dependency is a product decision, not an implementation detail.
- The app bundle is assembled by `scripts/make-app.sh`, not by Xcode. It is
  ad-hoc signed; there is no Apple Developer ID, so no notarization.

## Commands

```bash
swift build                                                        # compile
swift run                                                          # launch from the build dir
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test   # tests
./scripts/make-app.sh release                                      # bundle + install to ~/Applications
./scripts/release.sh X.Y.Z                                         # cut a release
```

`swift test` needs XCTest, which ships with Xcode rather than the Command Line
Tools. On machines where Xcode is installed but not selected, prefix the
command with `DEVELOPER_DIR` as shown instead of changing `xcode-select`.

## Architecture

- **Day indices, not Dates.** All timeline maths uses whole days counted from
  2000-01-01 in a Gregorian calendar (`Support/DayMath.swift`). A plan is an
  inclusive range of days; there is no time of day anywhere.
- **`Viewport`** maps days to pixels with two numbers, `pixelsPerDay` and
  `leftDay`. Its `width` is floored at 1 so a zero-width layout pass cannot
  turn the mapping into infinities.
- **`EventLayout`** stacks bars greedily into rows and culls those off screen.
  It is pure geometry and has unit tests.
- **`GridRenderer`** draws the ruler and gridlines. A single `Tier`
  (days / months / years) decides the granularity for both, so they cannot
  disagree about the zoom level.
- **`AppModel`** is the observable store. Writes go through `write(_:_:)`,
  which logs failures; reads return `nil` on failure so a failed refresh never
  replaces the timeline with an empty one.
- **`Database`** wraps SQLite: one `events` table, schema migration on open.

## Rules that are easy to break

- **Every SQL value is a bound parameter.** Never interpolate plan text into
  SQL.
- **Schema changes go in two places:** the `CREATE TABLE` statement and the
  `addedColumns` list in `Database.swift`, so older databases are migrated on
  open. `DatabaseTests` covers the migration path.
- **Never log plan contents** — titles, descriptions, tags or locations. Log
  the operation name and the error only.
- **Do not use `Bundle.module`** to load resources. Its generated accessor
  looks beside the `.app` rather than inside `Contents/Resources`, then falls
  back to the absolute build path of the machine that compiled it, and
  `fatalError`s when neither exists — a crash on every machine but the
  builder's. `PlannerView.appLogo` shows the search to use instead.
- **Date formatters come from `DayMath.formatter(for:)`**, which pins the
  calendar to the timeline's Gregorian one while month names still follow the
  user's language.
- **The palette is final.** The accent colours used for dates and descriptions
  sit below WCAG AA contrast on their fills; the author reviewed this and chose
  to keep the design. Do not "fix" it.
- **Accessibility conventions:** icon-only buttons get an
  `accessibilityLabel`; each plan bar is a single VoiceOver element with Edit
  and Delete actions; decoration (gridlines, logo, backdrops) is hidden from
  assistive technology; animations respect Reduce Motion.

## Working on this machine

- **Do not launch the app repeatedly or from parallel agents.** Every launch
  opens a window on the author's screen. If a change needs a visual check,
  launch once and say so, or ask the author for a screenshot.
- **The author's real plans** live in
  `~/Library/Application Support/Softplan/softplan.sqlite`. Never modify or
  delete that file. Tests use a temporary directory (`Database(directory:)`)
  and a scratch `UserDefaults` suite (`Viewport(defaults:)`).
- Build output lives in `.build/` and `dist.noindex/`, both git-ignored. The
  `.noindex` suffix keeps Spotlight from listing build copies of the app.

## Versioning and releases

- [Semantic Versioning](https://semver.org): PATCH for fixes, MINOR for
  features, MAJOR for changes people must adapt to. The first public release
  is **1.0.0**.
- The version lives in `App/Info.plist` (`CFBundleShortVersionString`, plus an
  always-increasing `CFBundleVersion` build number).
- Release notes are the matching `## [X.Y.Z]` section of `CHANGELOG.md`,
  written for people using the app.
- `scripts/release.sh X.Y.Z` does the rest: bump, test, build, zip with a
  SHA-256 checksum, tag `vX.Y.Z`, push, and publish the GitHub Release through
  the `gh` CLI.
- `make-app.sh` runs `strip -S -x` on release binaries before signing. Without
  it, a published build carries the absolute path of every source folder and
  object file on the machine that built it. Keep the strip before `codesign`.
- **In-app auto-update is deliberately not built yet.** Sparkle was evaluated:
  it works without a Developer ID (it trusts its own EdDSA signature, and
  accepts ad-hoc signed apps), but it adds a dependency, a network call and a
  signing key that must never be lost. For now people update by downloading
  the newest release.

## Out of scope, on purpose

Dark mode, sync or sharing, multiple timelines, and time-of-day events. The
editor's location, category and tags are stored and editable but not yet
shown on the bars.

## Known issues

- A failed save is logged but not shown to the user; the plan stays on screen
  as if it had saved.
- The draw-to-create preview can land one row off once a plan is expanded.
- Saving from an editor whose plan was deleted underneath it re-creates the
  plan.
