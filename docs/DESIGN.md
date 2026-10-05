# Native design and content provenance

## Navigation

User requirement: preserve the existing website hierarchy and links. The five website sections remain peer destinations in their existing order. Map and saved items are subordinate tools within Sites. Each tab owns a NavigationStack. On iPad, the standard sidebar-adaptable TabView provides more room while keeping the same destinations.

The website's secondary navigation and footer links are grouped in a labeled system menu. Site and directory rows push details. Filters use a self-contained modal form with Cancel, Reset, and Apply. Sharing uses the system share sheet. No custom tab bar or navigation gestures are introduced.

## Appearance and accessibility

- System controls supply platform materials and appearance, including current system navigation styling.
- A restrained green accent and serif editorial titles distinguish the content; grouped lists keep reading and browsing familiar.
- Semantic fonts support Dynamic Type; text is not assigned fixed heights.
- Native labels, explicit names for icon buttons, and combined row accessibility labels support VoiceOver.
- Maps have an equivalent list path, and save actions are available in toolbars as well as swipe menus.
- Semantic foreground/background colors adapt to appearance. The accent has separate light and dark variants.
- No decorative motion or custom transparency layer is required.

These choices are informed by the relevant HIG, not a claim of complete HIG certification. Before release, audit VoiceOver order, maximum Dynamic Type, increased contrast, reduced transparency, landscape, iPad resizing, and physical-device touch targets. The five exact website labels, particularly Classifications, need small-screen review.

## Apple references

- https://developer.apple.com/design/human-interface-guidelines/tab-bars
- https://developer.apple.com/design/human-interface-guidelines/toolbars
- https://developer.apple.com/design/human-interface-guidelines/menus
- https://developer.apple.com/design/human-interface-guidelines/layout
- https://developer.apple.com/design/human-interface-guidelines/accessibility
- https://developer.apple.com/design/human-interface-guidelines/materials

## Live content

Catalogs and detail records load from the production API. Native text displays the API descriptions and provenance flags. Related record links use the IDs and slugs supplied by the API. Missing coordinates are omitted from Map; no location is fabricated. No third-party imagery is bundled.

The client displays supplied dates without silently correcting the API's BP conventions. Source IDs remain numeric. Full media and rich HTML formatting remain on the original website; text links and citation anchors are preserved as reference links.

## Verification

The Simulator build and model/network regression checks pass. Live checks loaded all pages for Sites (642), Classifications (86), Time periods (14), Cultures (7), and Sources (835), and loaded detail records for each section. Source pagination required explicit ID sorting to avoid duplicate rows. The Laetoli-to-source-to-site relationship was checked against live responses. These counts are observations, not hard-coded app values.

The live Xcode UI test passed on iPhone 17e / iOS 27.2: all five tabs, catalog search, site detail navigation, bookmark persistence across relaunch, removal, and empty state. Search fields are always visible at the top of catalog pages. Full VoiceOver and cross-device audits remain outstanding.
