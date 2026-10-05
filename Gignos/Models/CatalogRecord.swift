import Foundation

struct CatalogRecord: Identifiable, Hashable, Codable, Sendable {
    let section: WebsiteSection
    let key: String
    let title: String
    var country = ""
    var kind = ""
    var subtitle = ""
    var summary = ""
    var body = ""
    var wikipediaDerived = false
    var latitude: Double?
    var longitude: Double?
    var facts: [RecordFact] = []
    var externalLinks: [RecordLink] = []
    var id: String { section.rawValue + "/" + key }
    var url: URL { section.url.appendingPathComponent(key) }
    var hasCoordinate: Bool {
        guard let latitude, let longitude else { return false }
        return latitude.isFinite && longitude.isFinite && (-90...90).contains(latitude) && (-180...180).contains(longitude)
    }
    func matches(_ query: String) -> Bool {
        let text = [title, subtitle, country, kind, summary].joined(separator: " ")
        return query.split(whereSeparator: \.isWhitespace).allSatisfy { text.localizedStandardContains(String($0)) }
    }
}

struct RecordFact: Hashable, Codable, Sendable {
    let label: String
    let value: String
}

struct RecordLink: Identifiable, Hashable, Codable, Sendable {
    let title: String
    let url: URL
    var id: String { url.absoluteString }

    static func safeURL(_ value: String?, relativeTo base: URL? = nil) -> URL? {
        guard let value, !value.isEmpty, let url = URL(string: value, relativeTo: base)?.absoluteURL,
              ["https", "http"].contains(url.scheme?.lowercased() ?? ""), url.host != nil else { return nil }
        return url
    }
}

struct RelatedGroup: Identifiable, Codable, Sendable {
    let title: String
    let records: [CatalogRecord]
    var id: String { title }
}

struct RecordDetail: Codable, Sendable {
    let record: CatalogRecord
    let groups: [RelatedGroup]
}

enum CatalogSort: String, CaseIterable, Identifiable {
    case name = "Name", country = "Country"
    var id: String { rawValue }
}

struct CatalogFilter: Equatable {
    var query = ""
    var kind = "All types"
    var country = "All countries"
    var sort = CatalogSort.name
    var isActive: Bool { kind != "All types" || country != "All countries" }
    func apply(to records: [CatalogRecord]) -> [CatalogRecord] {
        records.filter {
            $0.matches(query) && (kind == "All types" || $0.kind == kind)
                && (country == "All countries" || $0.country == country)
        }.sorted {
            let left = sort == .name ? $0.title : $0.country + $0.title
            let right = sort == .name ? $1.title : $1.country + $1.title
            return left.localizedStandardCompare(right) == .orderedAscending
        }
    }
}
