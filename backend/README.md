# Amenities backend

A Cloudflare Worker that tells the app what a court's Google reviews say
about it: indoor or outdoor, lights, free, court count, dedicated courts, and
whether nets are provided. The app's amenity badges use these answers where
they exist and fall back to the name-based guess in `Amenities.swift`
everywhere else.

```
app ──POST /amenities {placeIds}──▶ Worker ──▶ KV cache (per place id)
                                      │ miss
                                      ├──▶ Google Place Details (reviews)
                                      └──▶ Claude (structured output)
```

The app sends **place ids only**. The Worker fetches the reviews itself, so
the endpoint can't be used as a general-purpose Claude proxy, and no
Anthropic key ships in the app. Answers are cached for 30 days. Bump
`CACHE_VERSION` in `src/index.ts` after changing the prompt or schema.

## Setup

```bash
cd backend
npm install
npx wrangler kv namespace create AMENITIES      # paste the id into wrangler.toml
npx wrangler secret put ANTHROPIC_API_KEY
npx wrangler secret put GOOGLE_PLACES_SERVER_KEY
npm run deploy
```

Then set `AMENITIES_API_HOST` in `../Secrets.xcconfig` to the deployed host
(for example `tickle-my-pickle-amenities.<you>.workers.dev`, without
`https://`) and run `xcodegen generate`.

`GOOGLE_PLACES_SERVER_KEY` must be a **separate** key from the app's.
The app's key is restricted to the iOS bundle id, and a Worker can't send
that restriction's header honestly. Give this key an API restriction of
Places API (New) only.

For local dev, put both secrets in `.dev.vars` (gitignored) and run
`npm run dev`.

## Before shipping

- **Abuse:** the endpoint has no auth yet. The place-id-only input and the
  cache limit the damage, but someone could still spend money on uncached
  ids. Add App Attest or a Cloudflare rate-limiting rule before release.
- **App privacy label:** place ids now go to your own server, and reviews go
  to Anthropic from there. Update the App Store privacy answers to match.
- **Google terms:** check that caching the derived answers fits Places API
  policy for your use. The Worker caches Claude's summary, not the raw
  review text.
