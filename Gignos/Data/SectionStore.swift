import Foundation
import Observation

/// UI state for one catalog tab, backed by the on-device cache.
///
/// load():  show cached rows right away
///       -> nothing cached? grab page 1 so the screen isn't empty
///       -> sync the full section in the background if it's partial or stale
///       -> re-run the current search against the fresh copy
///
/// A failed sync never clears what's cached. `isComplete` is what the UI uses to
/// avoid passing off a partial search as a full one.
@MainActor @Observable
final class SectionStore {
    let section: WebsiteSection
    private(set) var results: [CatalogRecord] = []
    private(set) var facets = CatalogFacets()
    private(set) var cachedCount = 0
    private(set) var expectedCount = 0
    private(set) var isComplete = false
    private(set) var isSyncing = false
    private(set) var syncedCount = 0
    private(set) var lastSynced: Date?
    private(set) var error: String?

    var hasContent: Bool { cachedCount > 0 }

    static let staleAfter: TimeInterval = 12 * 60 * 60

    private let db: AppDatabase
    private let api: any CatalogServing
    @ObservationIgnored private var filter = CatalogFilter()
    @ObservationIgnored private var didLoad = false

    init(section: WebsiteSection, db: AppDatabase = .shared, api: any CatalogServing = GignosAPI()) {
        self.section = section
        self.db = db
        self.api = api
    }

    private var isStale: Bool {
        guard let lastSynced else { return true }
        return Date().timeIntervalSince(lastSynced) > Self.staleAfter
    }

    func load() async {
        var first: CatalogPage?
        if !didLoad {
            didLoad = true
            await readCache()
            if !hasContent { first = await fetchFirstPage() }
        }
        if !isComplete || isStale { await sync(startingWith: first) }
    }

    /// Also used for pull to refresh.
    func sync(startingWith first: CatalogPage? = nil) async {
        guard !isSyncing else { return }
        isSyncing = true
        error = nil
        syncedCount = 0
        defer { isSyncing = false }
        do {
            let page1: CatalogPage
            if let first { page1 = first } else { page1 = try await api.page(section, number: 1) }
            guard page1.page == 1 else { throw APIError.invalidResponse }
            expectedCount = page1.total
            let records = try await CatalogDownloader(api: api).downloadAll(section, first: page1) { [weak self] count in
                self?.syncedCount = count
            }
            try await db.replace(section, with: records, total: page1.total, isComplete: true)
            await readCache()
        } catch is CancellationError {
        } catch let failure as URLError where failure.code == .cancelled {
        } catch {
            self.error = error.localizedDescription   // cached copy stays untouched
        }
    }

    /// Called (debounced) whenever search text, filters, or sort change.
    func apply(_ filter: CatalogFilter) async {
        self.filter = filter
        do {
            let found = try await db.search(section, filter: filter)
            guard !Task.isCancelled else { return }
            results = found
        } catch is CancellationError {
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func fetchFirstPage() async -> CatalogPage? {
        do {
            let first = try await api.page(section, number: 1)
            guard first.page == 1 else { throw APIError.invalidResponse }
            try await db.replace(section, with: first.records, total: first.total, isComplete: first.totalPages <= 1)
            await readCache()
            return first
        } catch is CancellationError {
        } catch let failure as URLError where failure.code == .cancelled {
        } catch {
            self.error = error.localizedDescription
        }
        return nil
    }

    private func readCache() async {
        do {
            let state = try await db.state(section)
            cachedCount = try await db.count(section)
            isComplete = state?.isComplete ?? false
            if let total = state?.total { expectedCount = total }
            lastSynced = state?.isComplete == true ? state?.syncedAt : nil
            facets = try await db.facets(section)
            results = try await db.search(section, filter: filter)
        } catch {
            self.error = error.localizedDescription
        }
    }
}
