import Foundation
import Observation

@MainActor @Observable
final class CatalogStore {
    private(set) var records: [CatalogRecord] = []
    private(set) var isLoading = false
    private(set) var loadedCount = 0
    private(set) var expectedCount = 0
    private(set) var hasLoaded = false
    private(set) var error: String?
    private(set) var updatedAt: Date?
    let section: WebsiteSection
    private let api: any CatalogServing

    init(section: WebsiteSection, api: any CatalogServing = GignosAPI()) {
        self.section = section
        self.api = api
    }
    func loadIfNeeded() async { if !hasLoaded { await reload() } }
    func reload() async {
        guard !isLoading else { return }
        isLoading = true
        error = nil
        loadedCount = 0
        defer { isLoading = false }
        do {
            let first = try await api.page(section, number: 1)
            guard first.page == 1 else { throw APIError.invalidResponse }
            expectedCount = first.total
            var downloaded = first.records
            loadedCount = downloaded.count
            // Four bounded requests at a time. Publish atomically so search and
            // filters always describe a complete catalog, never just page one.
            if first.totalPages > 1 {
                for start in stride(from: 2, through: first.totalPages, by: 4) {
                    try Task.checkCancellation()
                    let end = min(start + 3, first.totalPages)
                    let api = self.api
                    let section = self.section
                    let pages = try await withThrowingTaskGroup(of: CatalogPage.self) { group in
                        for page in start...end { group.addTask { try await api.page(section, number: page) } }
                        var result: [CatalogPage] = []
                        for try await page in group { result.append(page) }
                        return result.sorted { $0.page < $1.page }
                    }
                    guard pages.map(\.page) == Array(start...end),
                          pages.allSatisfy({ $0.total == first.total && $0.totalPages == first.totalPages }) else { throw APIError.catalogChanged }
                    downloaded.append(contentsOf: pages.flatMap(\.records))
                    loadedCount = downloaded.count
                }
            }
            try Task.checkCancellation()
            guard downloaded.count == first.total, Set(downloaded.map(\.id)).count == downloaded.count else {
                throw APIError.catalogChanged
            }
            records = downloaded
            updatedAt = Date()
            hasLoaded = true
        } catch is CancellationError {
        } catch let failure as URLError where failure.code == .cancelled {
        } catch { self.error = error.localizedDescription }
    }
}

@MainActor @Observable
final class LibraryStore {
    private(set) var saved: [CatalogRecord] = []
    private(set) var error: String?
    private let defaults: UserDefaults
    private let key = "gignos.savedRecords.v1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: key) {
            do { saved = try JSONDecoder().decode([CatalogRecord].self, from: data) }
            catch { self.error = "Saved records couldn’t be read on this device." }
        }
    }
    func contains(_ record: CatalogRecord) -> Bool { saved.contains { $0.id == record.id } }
    func migratePreviewBookmarks(from records: [CatalogRecord]) {
        let oldIDs = defaults.stringArray(forKey: "gignos.savedSiteIDs") ?? []
        guard !oldIDs.isEmpty else { return }
        let matches = records.filter { $0.section == .sites && oldIDs.contains($0.key) }
        for record in matches where !contains(record) { saved.append(record) }
        persist()
        if error == nil {
            defaults.set(oldIDs.filter { id in !matches.contains { $0.key == id } }, forKey: "gignos.savedSiteIDs")
        }
    }
    func toggle(_ record: CatalogRecord) {
        if contains(record) { saved.removeAll { $0.id == record.id } }
        else { saved.append(record) }
        persist()
    }
    func update(_ record: CatalogRecord) {
        guard let index = saved.firstIndex(where: { $0.id == record.id }) else { return }
        saved[index] = record
        persist()
    }
    private func persist() {
        do { defaults.set(try JSONEncoder().encode(saved), forKey: key); error = nil }
        catch { self.error = "Your saved records couldn’t be stored." }
    }
}
