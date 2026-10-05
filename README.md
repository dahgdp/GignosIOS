# Gignos for iOS

Native SwiftUI client for iPhone and iPad, targeting iOS 18+. Open `Gignos.xcodeproj`, choose **Gignos** and an iPhone simulator, and press **⌘R**. One dependency, [GRDB](https://github.com/groue/GRDB.swift) (SQLite cache, resolved automatically by Swift Package Manager). No API keys or login are needed for the public catalog. Pick your team under Signing & Capabilities before running on a device.

## Navigation

The website's names, order, and canonical links are preserved:

| Tab | Website / API resource |
| --- | --- |
| Sites | `/sites` |
| Classifications | `/classifications` |
| Time periods | `/time_periods` |
| Cultures | `/cultures` |
| Sources | `/sources` |

Sites is the opening screen. Map and Saved records are within Sites. Home, About, News, Contact, Q&A, and Privacy Policy remain website links in the secondary menu. A separate native Home page has not been implemented.

## Live data

The app reads `https://gignos.com/research/api/v1`, the production API configured by the public Gignos web client. Each tab loads its complete catalog when first visited, following the API's ten-record pages with at most four concurrent requests. Loading progress is visible. Search, filters, and sorting operate on the complete downloaded catalog. Pull to refresh updates it. A failed refresh keeps the last complete result from the current session.

Opening a record fetches fresh detail and actual linked sites, classifications, time periods, cultures, cited sources, and related sources. Source URLs preserve numeric IDs; other entries preserve API slugs. Source authors are read from related people. Missing coordinates do not become map pins. Numeric site-type enums in related records are not guessed; opening the record fetches its display fields.

HTML descriptions become selectable native text with paragraph breaks and decoded entities. Original HTML links are retained in References & links, including citation anchors. Full media and original rich formatting remain available through the website link. This is not a web-view wrapper.

Saved records persist their text on this device and can be read offline. Opening one attempts a refresh and shows an error with the saved text if unavailable. Preview-era bookmarks migrate to matching live site records. The entire catalog is held in memory during the session; there is no disk catalog cache, account sync, or authenticated editing.

## Validation

```sh
xcodebuild -project Gignos.xcodeproj -scheme Gignos -sdk iphonesimulator -configuration Debug -derivedDataPath .build CODE_SIGNING_ALLOWED=NO build
swiftc -parse-as-library Gignos/Models/*.swift Tests/CatalogChecks.swift -o /tmp/gignos-catalog-checks
/tmp/gignos-catalog-checks
# Optional read-only production integration checks (downloads all five catalogs):
/tmp/gignos-catalog-checks --live
```

Checks cover response envelopes, optional values, ID/slug routes, numeric relationship enums, text/entity/link parsing, search and filters, HTTP failures, full pagination, incomplete refresh preservation, task cancellation, and saved-record persistence. See [API notes](docs/API.md) and [design notes](docs/DESIGN.md).

Verified: Xcode Simulator build and regression tests pass. Live integration checks loaded 642 sites, 86 classifications, 14 time periods, 7 cultures, and 835 sources, plus details and citation relationships. The app was installed and launched on iPhone 17e / iOS 27.2; the Sites screen was visually checked with live data. Counts may change as Gignos is updated. A live Xcode UI test now passes for all five tabs, search beyond the first page, site detail navigation, saving, persistence across relaunch, removal, and the empty saved state. A full accessibility audit and iPad testing remain outstanding.

### UI test in Xcode

Choose the **Gignos** scheme and an iPhone simulator, then press **⌘U**. `LiveCatalogUITests` reads the production API and therefore requires a network connection. It uses an isolated defaults suite so it does not change your saved records. Screenshots are retained in the test result bundle.
