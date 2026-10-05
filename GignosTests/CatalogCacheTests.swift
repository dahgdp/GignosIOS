import Foundation
import Testing
@testable import Gignos

private func site(_ key: String, _ title: String, country: String = "", kind: String = "") -> CatalogRecord {
    var record = CatalogRecord(section: .sites, key: key, title: title)
    record.country = country
    record.kind = kind
    return record
}

/// Three pages, one record each. `fails` simulates the API being down.
private struct StubAPI: CatalogServing {
    var fails = false
    func page(_ section: WebsiteSection, number: Int) async throws -> CatalogPage {
        if fails { throw APIError.http(503) }
        let record = CatalogRecord(section: section, key: "r\(number)", title: "Record \(number)")
        return CatalogPage(records: [record], page: number, total: 3, totalPages: 3)
    }
    func detail(_ record: CatalogRecord) async throws -> RecordDetail { .init(record: record, groups: []) }
}

@Suite struct CatalogCacheTests {
    @Test func searchFindsRecordsPastThePageOneRangeAndIgnoresAccents() async throws {
        let db = try AppDatabase.inMemory()
        let records = (1...300).map { site("s\($0)", "Filler \($0)") }
            + [site("laetoli", "Laetoli", country: "Tanzania"), site("cave", "Café Cave", country: "Italy", kind: "Cave")]
        try await db.replace(.sites, with: records, total: records.count, isComplete: true)

        var filter = CatalogFilter()
        filter.query = "laet"
        let prefix = try await db.search(.sites, filter: filter)
        #expect(prefix.map(\.key) == ["laetoli"])

        filter.query = "cafe ital"
        let accents = try await db.search(.sites, filter: filter)
        #expect(accents.map(\.key) == ["cave"])
    }

    @Test func replaceSwapsOneSectionAndLeavesNoStaleSearchHits() async throws {
        let db = try AppDatabase.inMemory()
        try await db.replace(.sites, with: [site("old", "Old Site")], total: 1, isComplete: true)
        try await db.replace(.sources, with: [CatalogRecord(section: .sources, key: "1227", title: "A source")], total: 1, isComplete: true)
        try await db.replace(.sites, with: [site("new", "New Site")], total: 1, isComplete: true)

        var filter = CatalogFilter()
        filter.query = "old"
        let stale = try await db.search(.sites, filter: filter)
        #expect(stale.isEmpty)
        let sources = try await db.search(.sources, filter: CatalogFilter())
        #expect(sources.map(\.key) == ["1227"])
    }

    @Test func filtersFacetsAndCountrySort() async throws {
        let db = try AppDatabase.inMemory()
        try await db.replace(.sites, with: [
            site("b", "Bravo", country: "Kenya", kind: "Cave"),
            site("a", "Alpha", country: "Spain", kind: "Open-air"),
            site("c", "Charlie", country: "Chad", kind: "Cave"),
        ], total: 3, isComplete: true)

        var filter = CatalogFilter()
        filter.kind = "Cave"
        filter.sort = .country
        let caves = try await db.search(.sites, filter: filter)
        #expect(caves.map(\.key) == ["c", "b"])

        let facets = try await db.facets(.sites)
        #expect(facets.kinds == ["Cave", "Open-air"])
        #expect(facets.countries == ["Chad", "Kenya", "Spain"])
    }

    @Test func detailRoundTrips() async throws {
        let db = try AppDatabase.inMemory()
        let record = site("laetoli", "Laetoli")
        let detail = RecordDetail(record: record, groups: [RelatedGroup(title: "Sources", records: [CatalogRecord(section: .sources, key: "1227", title: "A source")])])
        try await db.store(detail)
        let cached = try await db.cachedDetail(record)
        #expect(cached?.groups.first?.records.first?.key == "1227")
    }
}

@MainActor @Suite struct SectionStoreTests {
    @Test func firstRunEndsWithACompleteCatalog() async throws {
        let store = SectionStore(section: .sites, db: try AppDatabase.inMemory(), api: StubAPI())
        await store.load()
        #expect(store.isComplete)
        #expect(store.results.count == 3)
        #expect(store.error == nil)
    }

    @Test func failedRefreshKeepsTheCachedCopy() async throws {
        let db = try AppDatabase.inMemory()
        try await db.replace(.sites, with: [site("laetoli", "Laetoli")], total: 1, isComplete: true)
        let store = SectionStore(section: .sites, db: db, api: StubAPI(fails: true))
        await store.load()   // cache is fresh, so no network yet
        await store.sync()   // pull to refresh while the API is down
        #expect(store.results.map(\.key) == ["laetoli"])
        #expect(store.isComplete)
        #expect(store.error != nil)
    }

    @Test func failedFirstSyncIsReportedAsPartial() async throws {
        let db = try AppDatabase.inMemory()
        try await db.replace(.sites, with: [site("r1", "Record 1")], total: 3, isComplete: false)
        let store = SectionStore(section: .sites, db: db, api: StubAPI(fails: true))
        await store.load()
        #expect(!store.isComplete)
        #expect(store.cachedCount == 1 && store.expectedCount == 3)
    }
}
