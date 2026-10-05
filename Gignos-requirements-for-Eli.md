# Gignos native iOS app — requirements for Eli

Prepared September 27, 2026 • Draft for scope and estimate

## Assignment

Eli, build, publish, and maintain a polished native Gignos app for iPhone and iPad. It should let people accomplish the same public browsing and research tasks as the Gignos website, with navigation and interactions designed for iOS. Use the supplied SwiftUI sample as a working reference. You may improve or replace its implementation while preserving the agreed functionality and content relationships.

You are responsible for the engineering process through production: design, implementation, performance work, automated and manual testing, TestFlight, App Store submission through your own Apple Developer account, review fixes, release, and ongoing maintenance.

Performance thresholds and maintenance response times below are proposed acceptance targets for agreement before development. They are not measurements of the sample or commitments already accepted by Eli. No release date, price, or maintenance term has been agreed.

## 1. Reference material and current baseline

- Product reference: [Gignos website](https://gignos.com).
- Sample: `Gignos-iOS/` in the accompanying handoff ZIP. Open `Gignos.xcodeproj`; select the Gignos scheme. The current sample targets iOS 18+ and has no third-party dependencies or required login for public catalog access.
- Read its `README.md`, `docs/API.md`, and `docs/DESIGN.md`. The ZIP also includes model/network checks, an Xcode UI test, and screenshots from earlier verification.
- The sample connects to the public API at `https://gignos.com/research/api/v1` and provides five catalogs, details, related records, search, filters, sorting, a map, sharing, and persistent saved records.
- Prior project history reports passing simulator, model/network, and live UI checks. Those checks covered all five tabs, finding Laetoli Site G beyond the first page, opening its details, and saving/removing a bookmark across an app restart. This brief does not constitute a fresh test run or production certification.
- Gaps include native Home, rich media, classification hierarchy presentation, confirmed server-side search/filter behavior, persistent catalog caching, Universal Links, complete accessibility testing, and physical-device/iPad validation.

The sample is a reference implementation, not evidence that website parity or release readiness is complete.

## 2. Define and deliver website parity

Before implementation, audit the live website and produce a parity checklist: website URL/flow, expected behavior, native destination, data dependency, acceptance test, and status. Include secondary pages and linked content. Review this checklist with Derek; record any approved exception explicitly. The website defines intended product behavior, while known website bugs should be documented and resolved rather than copied.

### Navigation and Home

Preserve Sites, Classifications, Time periods, Cultures, and Sources as the five peer sections, in that order. Use native navigation, back behavior, search, sheets, and sharing. Preserve position and filters when users return from a detail page or switch tabs.

Add a native Home experience covering the website introduction, discovery/search entry points, map access, and recently added sites. Proposed placement: Home is the opening page inside Sites, with the site catalog one level below it. Confirm this design at the first milestone; the sample currently opens directly on the site catalog.

Keep About, News, Contact, Q&A, and Privacy Policy accessible. Agree in the parity checklist which secondary destinations remain web pages. Core catalog browsing, searching, and record details must work natively. The [website homepage](https://gignos.com) is the reference for discovery content and secondary navigation.

### Catalogs, search, and filters

All five catalogs must contain the same public records and relevant display fields as the website, using current production data. Implement applicable website search, filtering, sorting, result counts, and reset behavior. Search and filters must cover the full relevant dataset, including records outside the first loaded page.

The website currently exposes site filters for name, type, function, classification, country, and time period; classifications expose taxonomic filters. Verify exact combination and sorting semantics during discovery. See [Sites](https://gignos.com/sites) and [Classifications](https://gignos.com/classifications).

Results must not silently omit records or show a partial count as a complete count. Preserve stable ordering across pages. Show distinct loading, no-results, empty, offline, and failure states, with useful retry and reset actions.

### Details, relationships, and media

Display available descriptions, metadata, dates, provenance, citations, source authors, and related records. Users must be able to follow site → classification/period/culture/source → related site journeys without dead ends. Preserve canonical website URLs when sharing or opening the original page.

Preserve meaningful rich text, reference links, and available media. Inventory image, video, audio, and 3D/embed types; implement an appropriate native or embedded viewer for each required type, with an explicit fallback for unsupported external content. Any media deferred to the website requires a documented scope decision. Media failure must not prevent reading the record.

Do not invent missing dates, coordinates, taxonomy relationships, or meanings for numeric enum values. Retain supplied provenance and date conventions until the product/backend owners approve a change.

### Map, saved records, and links

Provide a map/list path to sites, accurate supplied locations, usable selection, and access to site details. Match agreed filter behavior between list and map. Missing coordinates must not create fabricated pins. Preserve the website's intentional location precision; its [Sites reference](https://gignos.com/sites) explains the public location policy.

Users can save and remove records, find their saved collection, and read saved text offline. Saved records survive app termination and upgrades. Cached content clearly indicates when it cannot refresh; external media need not be downloaded for offline use. No cross-device sync is assumed for version 1.

### Universal Links

Universal Links are ordinary HTTPS links associated with an iOS app and its website. When the app is installed and the system permits app opening, a supported link can take the user directly to the corresponding native screen. Without the app, the same URL works on the website. Apple describes the two-way app/website association in [Allowing apps and websites to link to your content](https://developer.apple.com/documentation/xcode/allowing-apps-and-websites-to-link-to-your-content).

Use canonical Gignos website URLs for sharing and incoming links. Preserve the website hierarchy: supported catalog links select the matching Sites, Classifications, Time periods, Cultures, or Sources tab; record links open that record within the appropriate tab. Map the website root to the agreed Home destination once Home placement is confirmed. During discovery, document the exact production paths, record identifiers, supported query parameters, and fragments in a route matrix. Preserve numeric source IDs where required rather than assuming every record uses a slug. API, administrative, and other web-only routes must remain website destinations.

Implementation requirements:

- **App and domain configuration:** Eli must enable Associated Domains for the production app and include `applinks:gignos.com`. Add other hosts only if they actually serve supported canonical links, and configure each supported host. The website owner must serve an `apple-app-site-association` (AASA) file, without a filename extension, at `https://gignos.com/.well-known/apple-app-site-association`, publicly accessible over HTTPS without redirects. Its application identifier must match the signed production app, and its URL rules must cover the agreed native routes. Coordinate this using Eli's publishing account and actual app identifier; do not assume a development build's identity is the release identity. See [Supporting associated domains](https://developer.apple.com/documentation/xcode/supporting-associated-domains).
- **SwiftUI routing:** Receive incoming Universal Links through [onOpenURL(perform:)](https://developer.apple.com/documentation/swiftui/view/onopenurl%28perform%3A%29). Use a shared URL router that validates the scheme, host, path, and parameters, selects the appropriate tab, and resolves the requested record. Support both a terminated app launching from a link and an already-running app receiving one. Opening a record must not require downloading every catalog first. Missing records, unavailable network access, and malformed links need useful recovery states. Apple's [Supporting Universal Links in your app](https://developer.apple.com/documentation/xcode/supporting-universal-links-in-your-app) also explains incoming-link handling and URL validation.
- **Website fallback:** Preserve usable canonical web pages for people without the app and for web-only content. Respect the user's choice to stay in the browser. Do not promise that every Safari navigation launches the app: same-domain browsing can remain in Safari, and typing a URL into Safari's address bar is not an app-opening test. Provide an explicit way to view original web content without repeatedly reopening the same native destination.

Acceptance requires tests on physical iPhone and iPad devices for supported catalog and record links, cold and warm launches, the app absent, numeric source identifiers, supported query/fragment behavior, nonexistent records, and offline operation. Check that links select the correct tab and detail and leave a usable navigation path. Test links tapped or long-pressed from Notes or another app, and verify the signed release configuration as well as development builds. Follow Apple's [TN3155: Debugging Universal Links](https://developer.apple.com/documentation/technotes/tn3155-debugging-universal-links) for association diagnostics and browser-choice behavior; account for Apple's AASA CDN caching when testing configuration changes.

Deliver the route matrix, app entitlement configuration, proposed production AASA file, routing tests, and device verification steps. Domain association requires cooperation from the website owner; agree responsibility and any release exception before implementation. If the app later transfers developer accounts, include a review of the signed application identifier and website association in the transfer plan. These are delivery requirements, not a claim that the current sample already supports Universal Links.

## 3. Native design and accessibility

Use Swift and SwiftUI and follow Apple's [Human Interface Guidelines](https://developer.apple.com/design/human-interface-guidelines/). Match Gignos identity while using familiar platform controls. Support iPhone and iPad layouts, light/dark appearance, larger text, VoiceOver, adequate contrast, reduced motion, rotation, and supported iPad resizing. Confirm the minimum OS and physical-device matrix at kickoff; use iOS 18+ as the starting proposal.

Acceptance includes readable content at the largest supported text sizes, correctly labeled controls, sensible VoiceOver focus order, comfortable touch targets, no clipped tab labels, no broken keyboard interactions, and a non-map path to equivalent information. Review complete user journeys on real devices, not only screenshots or simulators.

## 4. Performance requirements

The sample downloads each complete catalog in ten-record pages before full search/filter use and holds the catalog in memory for that session. This is a known implementation risk for startup speed and growth. Redesign that loading approach as needed.

Render useful content incrementally, persist appropriate catalog/detail caches, and refresh in the background. Do not require a full catalog download before showing a usable first page. Search across the full dataset must remain correct: use confirmed server-side search or a complete local index with clear readiness status. Never disguise searching a partial download as complete search.

Use bounded concurrency, cancellation, timeouts, deduplicated requests, image sizing/caching, and lazy media loading. Avoid fetching unrelated tabs or large media during launch. Preserve previously usable data when refresh fails. Coordinate necessary API changes instead of relying on undocumented query parameters.

### Proposed measurable targets

Measure release builds on a named older supported physical iPhone and a current iPhone. Use at least 30 runs per timing scenario and report the 95th percentile—the time within which 95% of runs finish. Record device, OS, dataset, cache state, network profile, and backend latency.

| Scenario | Target |
| --- | --- |
| Cold launch to responsive navigation | ≤ 2 seconds |
| First install, no cache: first usable catalog records | ≤ 3 seconds on a controlled 20 Mbps / 50 ms latency connection |
| Relaunch with cached data: useful content | ≤ 1 second |
| Open cached detail or switch to a loaded tab | ≤ 300 ms |
| Local search/filter results | ≤ 300 ms after input debounce |
| Uncached detail or server search | ≤ 2 seconds on the same controlled connection |

Also test at 1 Mbps / 300 ms latency, offline launch, interrupted connections, server errors, and a dataset at least ten times the observed current catalog size. Cached content must remain usable; uncached failures need a bounded wait and retry path. Establish and document a request timeout budget, proposed maximum 15 seconds per visible attempt.

Profile scrolling, memory, CPU, network traffic, and battery impact with Instruments. Address visible scrolling hitches and unbounded memory growth. Report end-to-end latency, including backend delay; identify backend blockers and agree a remedy or revised target rather than excluding that delay from results.

## 5. Engineering and release quality

Derek will import the sample app into the Gignos team's repository. That repository is the source of truth for Eli's implementation, tests, documentation, release assets, and maintenance changes; the accompanying ZIP is a reference snapshot. Eli should work through branches and pull requests there. Use reviewed changes, reproducible builds, versioned releases, and continuous integration for builds and deterministic tests. Keep networking, data persistence, and presentation separable enough to test and maintain.

Automate tests for API parsing, pagination completeness and stable ordering, full-dataset search/filter logic, missing data, linked records, citations, cache refresh/failure, saved-record persistence and migration, cancellation, and malformed/failed responses. Add UI tests for the critical journeys in the parity checklist. Keep deterministic tests separate from read-only live API smoke tests.

The observed API has source records with numeric detail IDs, other records with slugs, mixed string/numeric page values, and source pagination that required explicit ID ordering to avoid duplicates. Preserve regression coverage for these cases and reconcile the adapter with the official backend contract. Backend repository access was unavailable during prototype work and must be arranged for production discovery.

Before release, complete device/OS, accessibility, offline, slow-network, interrupted-task, large-content, deep-link, fresh-install, and upgrade testing. Run a proposed minimum seven-day TestFlight round with Derek and representative testers. Re-test fixes and attach evidence to each release candidate.

Release gate: every required parity item passes; agreed performance targets pass; no known crash, data loss, security-critical issue, blocked core journey, or high-severity defect remains. Minor issues require documented impact, an owner, a target fix date, and Derek's acceptance. “No bugs” means a rigorous release gate and ongoing defect response, not a promise that no future defect can exist.

## 6. App Store publication through Eli's account

Eli will use and maintain his own Apple Developer Program account, configure production signing and the app identifier, manage TestFlight and App Store Connect, prepare the icon/screenshots/description/support and privacy links, complete applicable disclosures and ratings, submit the app, respond to review, and resolve rejection issues through publication.

Audit included SDKs, permissions, media/content rights, and actual data collection so App Store declarations match the shipped app. Keep public browsing usable without a new login unless an approved requirement needs one. Check current submission requirements at release time. Apple's [review guidelines](https://developer.apple.com/app-store/review/guidelines/) require release-ready testing, accurate metadata, and accessible backend services; Apple controls approval and timing.

Confirm the account type and public seller identity before creating the listing. With individual enrollment, Eli's legal name is the seller; see [Apple's enrollment guidance](https://developer.apple.com/help/account/membership/enrolling-in-the-app). This follows the requested publishing arrangement.

Document code/content ownership, authorization to publish Gignos, repository access, App Store Connect access where supported, responsibility for recurring fees, and the process for a future maintainer or account transfer. App transfers depend on Apple's eligibility criteria and account-holder actions; see [Apple's transfer process](https://developer.apple.com/help/app-store-connect/transfer-an-app/overview-of-app-transfer). Do not leave release assets or operating instructions available only on one developer's computer.

## 7. Maintenance responsibility

Eli owns ongoing mobile-app maintenance after launch: monitor crashes and performance, triage user reports, fix regressions, maintain OS/device compatibility, respond to API changes, update dependencies and store disclosures, renew necessary account/signing resources, and publish maintenance releases.

Proposed service expectations, to agree with scope and fees:

| Priority | Examples | Response and action target |
| --- | --- | --- |
| Critical | Widespread launch failure, data loss, serious security issue | Acknowledge within 1 business day; mitigation or hotfix submission target within 2 business days |
| High | Core feature unusable for a meaningful group of users | Acknowledge within 2 business days; fix or dated recovery plan within 5 business days |
| Normal | Minor defects and polish | Triage weekly; schedule in the next agreed maintenance release |

These are business-day targets, not a 24/7 commitment. Apple review time is outside the hotfix submission target. Define coverage hours/time zone and escalation contact before launch.

Review crash/performance signals each business day during the first two weeks, then weekly. Provide a monthly summary of app health, incidents, fixes, compatibility work, and upcoming risks. Test major iOS changes before public release where practical. Keep crash/performance monitoring proportionate and reflected in privacy disclosures.

Agree an initial maintenance term, included monthly effort or retainer, bug-fix versus new-feature boundaries, and renewal/exit arrangements before development starts. Backend operations remain with the existing backend owner unless separately assigned; Eli must diagnose and coordinate backend-dependent mobile issues through resolution. On handoff, deliver current source, build/release instructions, assets, open issues, and account-transfer assistance where eligible.

## 8. Milestones and definition of done

1. **Discovery:** approved parity checklist, Home/navigation design, API/dependency assessment, device matrix, performance plan, estimate, timeline, and maintenance terms.
2. **Functional beta:** all agreed journeys implemented using live data; automated tests pass; initial performance measurements provided.
3. **Release candidate:** TestFlight feedback addressed; physical-device/accessibility/network/upgrade tests complete; performance and defect gates met; Derek accepts the release candidate.
4. **Publication:** app approved and publicly available under Eli's developer account; production smoke tests pass; store listing and release documentation delivered. Submission alone does not complete this milestone.
5. **Maintenance:** agreed monitoring, defect handling, compatibility updates, and reporting are operating for the agreed term.

Deliver the repository and reproducible project, parity checklist, architecture/API/cache notes, test and performance report, store assets/listing, release checklist, support runbook, known-issues register, and maintenance schedule.

## 9. Scope decisions to settle at kickoff

Confirm budget/timeline, Home placement, supported devices/OS versions, required media viewers, permitted secondary web destinations, backend/domain access, publishing identity and ownership/access arrangements, launch pricing/regions, and maintenance term/fees/coverage.

Working scope is the public Gignos experience plus the sample's saved-record feature. Android, new editorial/admin tools, new account systems, cross-device sync, payments, and full offline media downloads are not assumed. If discovery finds an existing public website flow requiring any of these, flag it in the parity checklist for an explicit decision rather than silently omitting it.
