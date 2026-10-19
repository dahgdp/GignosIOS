# Gignos iOS — feature priorities

Prepared October 18, 2026 • Companion to [Gignos-requirements-for-Eli.md](Gignos-requirements-for-Eli.md)

## Purpose

The requirements document defines *what* version 1 must do: website parity, native design, performance, release, and maintenance. This document sets the *order* in which to build it and adds the native iOS features that should follow parity. Where they differ, the requirements document still governs acceptance; this one governs sequencing. Section references (§) point to the requirements document.

Priorities come from a review of gignos.com, the live API, and Eli's working repository (`ehunter831/GignosIOS`, as of its October 5 commits).

**Repository:** Eli's repository `ehunter831/GignosIOS` is the working repository for the app. This is an approved change to §5, which named the Gignos team repository.

## Where the app stands

Done or well underway in Eli's repository, beyond the original sample:

- On-device SQLite cache (GRDB) with full-text search. Shows cached rows immediately, syncs in the background, and keeps cached data when a refresh fails. This addresses much of §4's loading concern.
- Cache tests, an app icon, test-target signing, and an Xcode Cloud manifest.

Largest remaining gaps against the website:

| Gap | Website | App today | Data already in the API |
| --- | --- | --- | --- |
| Images | Hero photos, thumbnails, galleries | No images anywhere | `heroMediaPreview` on records; `relatedObjects.medias[].url` on details |
| Home | Mission, recently added sites, learn/research cards | Opens on an A–Z list | `updatedAt`, hero images |
| Site filters | Type, function, classification, country, time period, age range | Type and country only | `siteFunction`, `dateRangeMin`/`dateRangeMax`, relationships |
| Video and media | e.g. 4 videos on Laetoli Site G | None | `medias[].fileType`, `embedLinkCode`, `sourceUrl` |
| Classification hierarchy | Taxonomic browsing | Flat list of 86 | `ancestry`, `rank` |
| Universal Links | n/a | None | Website must serve the AASA file |

## Priority 0: version 1 parity, in build order

These are required by §2 and gate release. Build them in this order. Each one is either the biggest visible gap or unblocks the next.

### P0.1 Images
Thumbnails in catalog rows, a hero image on every record that has one, and a swipeable gallery of image media on detail pages. Show the image source and credit where the API supplies them (`heroMediaSourceNames`). Load lazily, size to the display, and cache (§4). A failed image must never block reading the record.

*Why first:* the most visible difference from the website, the data already exists, and Home (P0.2) depends on it.

### P0.2 Native Home
The opening page inside Sites (§2, placement to confirm): the Gignos introduction, search entry, map entry, and **Recently added sites** as photo cards. Link the *Learn about human origins* and *Research opportunities* content natively where it exists as records, otherwise to the website.

*Why:* it's the first impression for new users and App Store review. The current A–Z list says nothing about what Gignos is.

*Dependency:* confirm with the backend how the website chooses "recently added" (creation date vs. `updatedAt`) instead of guessing.

### P0.3 Full Sites filter and sort parity
Add site function, classification, time period, and age range (min/max BP) to the existing type and country filters. Add sort by age. Add taxonomic filters to Classifications (§2). The full catalog is now cached locally, so this is mostly UI work, but combination semantics must match the website. Verify them during the parity audit.

*Why:* searching and filtering is the core research task, and "everything older than 40,000 years in Iberia" can't be done in the app today.

### P0.4 Video and other media
Inventory media types across the catalog (§2). Play YouTube and other video embeds in a native or embedded player. Show a clear "Open on website" fallback for anything unsupported. Include an inventory of 3D model formats, which P2.2 needs.

### P0.5 Universal Links: start coordination now
The code is modest. The lead time is not: it needs Eli's Apple Developer account and production app ID, plus an `apple-app-site-association` file served from gignos.com (§2). **Start the account and website work in parallel with P0.1**, so it doesn't become the last blocker before release.

### P0.6 Classification hierarchy
Present classifications as a tree from the `ancestry` field (e.g. genus → species), with each node linking to its record and related sites.

### Release-gate work that runs alongside P0
Not features, but they run alongside and are required before release: accessibility and iPad pass (§3), performance measurement against the §4 targets, the parity checklist (§2), and device testing (§5).

## Priority 1: cheap native wins for version 1

Low cost, mostly built on P0 work, and they help with App Store guideline 4.2 (an app must offer more than a repackaged website). Include them in version 1 if the schedule allows. Otherwise make them the first update.

### P1.1 Spotlight and Handoff
Index cached records so a search for "Lascaux" in iOS Search opens the app's record. Advertise the current record as an `NSUserActivity`, so a page open in Safari on a Mac hands off to the iPhone and back. Shares routing with P0.5.

### P1.2 Offline trip download
Builds on the existing cache: "Download this region" stores the text plus hero images for every site in a country or region before a trip. Many sites are remote with poor coverage. Full offline video stays out of scope (§9).

### P1.3 Site of the Day widget
A home-screen widget with a site's photo, name, and age that opens the record. A daily reason to come back. Depends on P0.1.

## Priority 2: version 1.1 headline features

These are the features that make the app a better way to explore prehistory than the website. Each needs a short design review with Derek before building.

### P2.1 Near me and travel mode
"Sites near me" plus an optional alert when the user is traveling near a catalogued site.

Guardrails, which are not negotiable:
- Use only the same deliberately imprecise public coordinates as the website (see the [Sites location policy](https://gignos.com/sites)).
- No turn-by-turn directions to sites. Directions only to a public museum or visitor center if the data supports one.
- Location permission is "while using" by default. Any travel alerts are opt-in, and proximity is processed on the device.
- Update the App Store privacy disclosures (§6).

### P2.2 3D models in AR
The website promises 3D models. Show supported models with Apple's AR Quick Look (USDZ), so a life-size Laetoli footprint or a skull can be placed in the room. Depends on the P0.4 inventory: confirm source formats, conversion to USDZ, and **rights to redistribute each model in an app**.

### P2.3 Interactive deep-time timeline
A scrubbable timeline from about 3.6 million to 10,000 years BP. As you drag, the map and list show the sites and cultures active at that time. This is the signature screen most likely to make the app memorable, and the largest design effort on this list. It needs consistent date data, so date conventions remain as supplied (§2) until the backend owners decide otherwise.

## Priority 3: later

- **Personal notes and collections** on saved records (e.g. "Neanderthal sites in Iberia"), with Apple Pencil markup on iPad. Local only. Sync is out of scope (§9).
- **New-site notifications.** Needs a backend signal or push infrastructure. Revisit after launch.

## Stays on the website (record as approved exceptions in the parity checklist)

- Contributing, editing, and researcher or institution submissions ("Research opportunities"). No accounts in the app (§9).
- Dense comparison tables, exports, and multi-tab research.
- About, News, Q&A, Contact, Privacy Policy, and newsletter signup (in-app links).
- Search-engine discovery and sharing with people who don't have the app. Universal Links connect the two rather than replacing the web.

## Long-lead items for Derek

Start these now. They depend on people and accounts, not code.

1. **Apple Developer account and production app ID** (Eli). Blocks Universal Links, TestFlight, and the AASA file.
2. **AASA file on gignos.com** (website owner). See P0.5.
3. **Backend repository access** for Eli (`gignos/gignos-api`). Confirms search and filter semantics, the "recently added" definition, media types, and enum meanings (§5).
4. **Media and 3D rights review** before images, video, and models ship in a distributed app.

## Housekeeping

- `README.md` and `docs/API.md` in Eli's repository still say there is no disk catalog cache. Update them to describe the SQLite cache.
- The requirements document says the sample has no third-party dependencies. The app now uses GRDB. Record that as an approved dependency or revisit it.
- **Toolchain:** GRDB 7.11 requires Xcode 16.3+ (Swift 6.1). Agree on a minimum Xcode version and document it in the README, so every machine and Xcode Cloud build the same way.

## Decisions needed

1. Confirm Home as the opening page inside Sites (P0.2).
2. Approve P1 items for version 1 or the first update.
3. Approve the P2 guardrails for location features before design starts.
