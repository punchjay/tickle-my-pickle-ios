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

## Map water doesn't match the web app's color

The web app's retro map theme (`../tickle-my-pickle/docs/map-style.json`) colors
water `#2E5A86` via Google's Cloud-based JSON map styling. `CourtMapView.swift`
uses Apple MapKit instead (a deliberate choice — no map API key needed on iOS),
and MapKit's SwiftUI `Map` has no public API for recoloring individual features:
`.mapStyle(.standard(elevation:emphasis:pointsOfInterest:showsTraffic:))` only
exposes elevation, `.muted`/`.standard` emphasis, POI categories, and traffic —
nothing per-feature like water vs. land vs. roads. Confirmed against current
Apple docs (`MapStyle`, `MapStyle.standard(elevation:emphasis:pointsOfInterest:showsTraffic:)`)
as of 2026-09-18; this isn't a version gap, it's a real API gap.

Options, roughly in order of effort:

- **Approximate with `.standard(emphasis: .muted)`** — quick, no new
  dependencies, but desaturates the whole map together rather than targeting
  water specifically; won't hit `#2E5A86`.
- **Overlay real water geometry** — render a semi-transparent `#2E5A86`
  `MKPolygon`/overlay only over actual water bodies, sourced from bundled
  coastline/lake data (e.g. Natural Earth). Matches the visual intent without a
  new map SDK, but is real engineering: sourcing + bundling geo data, and won't
  be pixel-perfect at all zoom levels.
- **Switch to the Google Maps SDK for iOS** — reuse the exact same Cloud-styled
  Map ID and `map-style.json` as the React app for a true match. Requires
  adding the Google Maps iOS SDK dependency and an API key, which this app has
  so far deliberately avoided needing.

No decision made yet; revisit when visual parity with the web app becomes a
priority.

## No linter configured

There is no SwiftLint config in this repo and `swiftlint` is not installed, so
"lint" currently means nothing here — unlike the two web repos, which both run
ESLint and Prettier in CI. Either add SwiftLint (config + a CI step in the existing
`CI` workflow) or note deliberately that this repo lints via Xcode warnings only.
