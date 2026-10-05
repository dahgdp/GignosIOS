import Foundation

/// Downloads a whole section page by page and returns a validated, complete list.
/// Same checks as the old CatalogStore, but the result goes to the cache instead
/// of living in memory.
struct CatalogDownloader: Sendable {
    var api: any CatalogServing = GignosAPI()
    var maxConcurrentPages = 4

    func downloadAll(
        _ section: WebsiteSection,
        first: CatalogPage,
        progress: @MainActor @Sendable (Int) -> Void
    ) async throws -> [CatalogRecord] {
        var records = first.records
        await progress(records.count)
        if first.totalPages > 1 {
            for start in stride(from: 2, through: first.totalPages, by: maxConcurrentPages) {
                try Task.checkCancellation()
                let end = min(start + maxConcurrentPages - 1, first.totalPages)
                let api = self.api
                let pages = try await withThrowingTaskGroup(of: CatalogPage.self) { group in
                    for number in start...end { group.addTask { try await api.page(section, number: number) } }
                    var result: [CatalogPage] = []
                    for try await page in group { result.append(page) }
                    return result.sorted { $0.page < $1.page }
                }
                guard pages.map(\.page) == Array(start...end),
                      pages.allSatisfy({ $0.total == first.total && $0.totalPages == first.totalPages }) else {
                    throw APIError.catalogChanged
                }
                records += pages.flatMap(\.records)
                await progress(records.count)
            }
        }
        try Task.checkCancellation()
        guard records.count == first.total, Set(records.map(\.id)).count == records.count else {
            throw APIError.catalogChanged
        }
        return records
    }
}
