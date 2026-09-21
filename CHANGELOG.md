# Changelog

Every release of Softplan, newest first. Versions follow
[Semantic Versioning](https://semver.org) — `MAJOR.MINOR.PATCH`:

- **PATCH** (1.0.0 → 1.0.1): fixes only, nothing new to learn.
- **MINOR** (1.0.1 → 1.1.0): new features; everything that worked still works.
- **MAJOR** (1.1.0 → 2.0.0): a change people have to adapt to.

Each section below becomes the notes of its
[GitHub Release](https://github.com/Rishabh-codes-star/Softplan/releases), so
write it for the people using the app, not for the people building it.

## [1.0.0] - 2026-09-21

The first public release.

- One horizontal timeline for every plan, zooming from about twelve years down
  to a single week.
- Sketch a plan by dragging across empty canvas, double-click for a month-long
  one, or press `⌘N`.
- Drag a bar to move it and pull its edges to change the dates; everything snaps
  to whole days.
- Fourteen earthy colour families, assigned automatically, least-used first.
- A description, location, category and tags on every plan; wide bars expand to
  show the description.
- Plans are stored in SQLite on your Mac — no account, and no network access.
- VoiceOver support, plan creation from the keyboard, and the system's Reduce
  Motion setting respected.
