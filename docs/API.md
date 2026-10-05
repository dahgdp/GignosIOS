# API contract observed September 27, 2026

Base URL: `https://gignos.com/research/api/v1`, found in `window.ENV.GIGNOS_API` on the public website. Read-only GET requests work without authentication. No secrets or private repository environment files are used.

## Lists

`GET /{sites|classifications|time_periods|cultures|sources}?page=N`

Responses are a two-element JSON array:

```json
[[{"slug":"example","name":"Example"}],{"page":"2","total":642,"total_pages":65}]
```

The first page can use a numeric page value; subsequent pages use strings. The adapter accepts both. Ten records are returned per page. `per_page=100` did not increase the page size. Website search query parameters sent directly to the API returned an unexpected bare empty array, so the client does not depend on that undocumented search contract.

A complete catalog is loaded with four concurrent requests at most. Counts, page numbers, and unique record IDs are checked before replacing the previous catalog. Cancellation stops the download; returning to an unfinished section retries. Requests time out after 30 seconds and require successful HTTP status codes.

Sources additionally send `sort_by=id&order=asc`. Without explicit ordering, a live pagination check returned 835 rows but only 825 unique IDs. With ID ordering, all 835 IDs were unique. The client still validates uniqueness to detect catalog changes during a download.

## Details

`GET /sites/{slug}`, `/classifications/{slug}`, `/time_periods/{slug}`, `/cultures/{slug}`, `/sources/{numericID}`

```json
[{"slug":"example","name":"Example"},{"relatedObjects":{"sites":[],"classifications":[],"timePeriods":[],"cultures":[],"citedSources":[],"relatedSources":[]}}]
```

Source detail IDs are numeric even though source records also contain slugs. Period names use `age`; classifications and cultures use `name`; sources use `title`. Some relationship payloads use numeric siteType/siteFunction enums while list and detail records have display strings. Unknown enum meanings are not inferred. Missing and null descriptions/coordinates are valid.

`showWikipediaDesc` chooses the Wikipedia description and corresponding provenance label. Dates and age ranges are displayed as supplied; no normalization of inconsistent BP conventions is attempted. Source authors come from `relatedObjects.people` with `creatorType == author`. HTML links resolve relative to the original Gignos record URL, preserving citations; only HTTP(S) destinations are exposed.

## Remaining scope

Embedded media, classification tree visualization, native secondary website pages, server-side search/filter semantics, authentication, write APIs, Universal Links, and offline full-catalog caching are not implemented. The main backend repository remains unavailable through the connected GitHub account. The observed public contract is isolated in `GignosAPI.swift` so it can be reconciled with official backend documentation later.
