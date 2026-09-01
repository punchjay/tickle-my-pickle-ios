# TODO

Design and App Store notes live in `CLAUDE.md` (gitignored, local only). This file
tracks repo-level chores only — don't duplicate the `## TODO:` sections there.

## Deleted branch `feat/web-visual-parity` — decide before ~27 Nov 2026

Commit `bee2e79` ("Match the web app's map, pins, and tab shapes") was force-deleted
on 2026-08-31. It was never pushed, so the local reflog is the only copy: 98 added
lines across `CourtListView.swift`, `CourtMapView.swift`, and `CourtPinView.swift`.

`CLAUDE.md` still documents this work under **"### Done (2026-08-29, branch
`feat/web-visual-parity`)"**, so the notes and the code now disagree. Resolve it one
way or the other:

- **Keep the work** — restore before the reflog expires. The clock runs 90 days
  from the commit's reflog entry of 2026-08-29, not from the deletion, per the
  default `gc.reflogExpire`:
  ```bash
  git branch feat/web-visual-parity bee2e79
  ```
- **Confirm it's gone** — delete that "Done" section from `CLAUDE.md`, and move the
  tab-shape, map-declutter, and teardrop-pin items back to still-open.

After ~27 Nov 2026 `gc` collects the object and the choice is made for you.

## No linter configured

There is no SwiftLint config in this repo and `swiftlint` is not installed, so
"lint" currently means nothing here — unlike the two web repos, which both run
ESLint and Prettier in CI. Either add SwiftLint (config + a CI step in the existing
`CI` workflow) or note deliberately that this repo lints via Xcode warnings only.
