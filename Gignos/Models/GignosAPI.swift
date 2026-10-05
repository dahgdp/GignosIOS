import Foundation

enum APIError: LocalizedError {
    case http(Int), invalidResponse, invalidRecord, catalogChanged
    var errorDescription: String? {
        switch self {
        case .http(let code): "Gignos returned an error (HTTP \(code)). Please try again."
        case .invalidResponse: "Gignos returned an unexpected response. Please try again later."
        case .invalidRecord: "A Gignos record couldn’t be read. Please try again later."
        case .catalogChanged: "The catalog changed while loading. Please refresh to get a complete copy."
        }
    }
}

// The public Rails API uses heterogeneous envelopes: [records, metadata] and
// [record, {relatedObjects: ...}]. Values in related records sometimes have
// numeric enum representations instead of the list endpoint's display strings.
enum JSONValue: Decodable, Sendable {
    case object([String: JSONValue]), array([JSONValue]), string(String), number(Double), bool(Bool), null
    init(from decoder: any Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { self = .null }
        else if let v = try? c.decode(Bool.self) { self = .bool(v) }
        else if let v = try? c.decode(Double.self) { self = .number(v) }
        else if let v = try? c.decode(String.self) { self = .string(v) }
        else if let v = try? c.decode([JSONValue].self) { self = .array(v) }
        else { self = .object(try c.decode([String: JSONValue].self)) }
    }
    var object: [String: JSONValue]? { if case .object(let v) = self { v } else { nil } }
    var array: [JSONValue]? { if case .array(let v) = self { v } else { nil } }
    var text: String? { if case .string(let v) = self { v } else { nil } }
    var number: Double? {
        switch self { case .number(let v): v; case .string(let v): Double(v); default: nil }
    }
    var integer: Int? {
        guard let n = number, n.isFinite, n.rounded() == n, n >= 0, n < Double(Int.max) else { return nil }
        return Int(n)
    }
    var bool: Bool { if case .bool(let v) = self { v } else { false } }
}

struct CatalogPage: Sendable {
    let records: [CatalogRecord]
    let page: Int
    let total: Int
    let totalPages: Int
}

protocol CatalogServing: Sendable {
    func page(_ section: WebsiteSection, number: Int) async throws -> CatalogPage
    func detail(_ record: CatalogRecord) async throws -> RecordDetail
}

struct GignosAPI: CatalogServing {
    static let productionURL = URL(string: "https://gignos.com/research/api/v1")!
    let baseURL: URL
    let session: URLSession

    init(baseURL: URL = Self.productionURL, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }

    func page(_ section: WebsiteSection, number: Int) async throws -> CatalogPage {
        var components = URLComponents(url: baseURL.appendingPathComponent(section.rawValue), resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "page", value: String(number))]
        if section == .sources {
            // Default source ordering produced duplicate records across pages.
            // The API honors this explicit ordering by unique source ID.
            components.queryItems?.append(contentsOf: [URLQueryItem(name: "sort_by", value: "id"), URLQueryItem(name: "order", value: "asc")])
        }
        return try Self.decodePage(await fetch(components.url!), section: section)
    }

    func detail(_ record: CatalogRecord) async throws -> RecordDetail {
        let url = baseURL.appendingPathComponent(record.section.rawValue).appendingPathComponent(record.key)
        return try Self.decodeDetail(await fetch(url), section: record.section)
    }

    private func fetch(_ url: URL) async throws -> Data {
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 30)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, response) = try await session.data(for: request)
        guard let response = response as? HTTPURLResponse else { throw APIError.invalidResponse }
        guard (200..<300).contains(response.statusCode) else { throw APIError.http(response.statusCode) }
        return data
    }

    static func decodePage(_ data: Data, section: WebsiteSection) throws -> CatalogPage {
        guard let envelope = try JSONDecoder().decode(JSONValue.self, from: data).array,
              envelope.count == 2, let rows = envelope[0].array, let meta = envelope[1].object,
              let page = meta["page"]?.integer, let total = meta["total"]?.integer,
              let pages = meta["total_pages"]?.integer, page >= 1, pages <= 1000,
              (pages >= page || (total == 0 && pages == 0)) else { throw APIError.invalidResponse }
        return CatalogPage(records: try rows.map { try record($0, section: section) }, page: page, total: total, totalPages: pages)
    }

    static func decodeDetail(_ data: Data, section: WebsiteSection) throws -> RecordDetail {
        guard let envelope = try JSONDecoder().decode(JSONValue.self, from: data).array,
              envelope.count == 2, let related = envelope[1].object?["relatedObjects"]?.object else { throw APIError.invalidResponse }
        var record = try record(envelope[0], section: section)
        if section == .sources, let people = related["people"]?.array {
            let names = people.compactMap { person -> String? in
                guard let o = person.object, o["creatorType"]?.text == "author" else { return nil }
                let name = [o["firstName"]?.text, o["lastName"]?.text].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " ")
                return name.isEmpty ? nil : name
            }
            if !names.isEmpty { record.facts.append(RecordFact(label: "Authors", value: names.joined(separator: ", "))) }
        }
        let mappings: [(String, String, WebsiteSection)] = [
            ("sites", "Sites", .sites), ("classifications", "Classifications", .classifications),
            ("timePeriods", "Time periods", .timePeriods), ("cultures", "Cultures", .cultures),
            ("citedSources", "Cited sources", .sources), ("relatedSources", "Related sources", .sources)
        ]
        let groups = try mappings.compactMap { key, title, section -> RelatedGroup? in
            guard let rows = related[key]?.array, !rows.isEmpty else { return nil }
            return RelatedGroup(title: title, records: try rows.map { try Self.record($0, section: section) })
        }
        return RecordDetail(record: record, groups: groups)
    }

    static func record(_ value: JSONValue, section: WebsiteSection) throws -> CatalogRecord {
        guard let o = value.object else { throw APIError.invalidRecord }
        let key = section == .sources ? o["id"]?.integer.map(String.init) : o["slug"]?.text
        let nameKey = section == .sources ? "title" : section == .timePeriods ? "age" : "name"
        guard let key, !key.isEmpty, let name = o[nameKey]?.text, !name.isEmpty else { throw APIError.invalidRecord }
        func text(_ key: String) -> String { (o[key]?.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines) }
        var r = CatalogRecord(section: section, key: key, title: HTMLContent.plainText(name))
        r.country = text("countryName")
        r.kind = text("siteType") // Do not invent names for undocumented numeric enums.
        r.latitude = o["latitude"]?.number
        r.longitude = o["longitude"]?.number
        r.wikipediaDerived = o["showWikipediaDesc"]?.bool ?? false
        let summaryHTML = r.wikipediaDerived ? text("wikipediaDescription") : text("shortDescription")
        r.summary = HTMLContent.plainText(summaryHTML)
        r.body = HTMLContent.plainText(text("longDescription"))
        let subtitleKeys: [String]
        switch section {
        case .sites: subtitleKeys = ["countryName", "siteType"]
        case .classifications: subtitleKeys = ["rank", "ageRange"]
        case .timePeriods: subtitleKeys = ["period", "epoch"]
        case .cultures: subtitleKeys = ["ageRange"]
        case .sources: subtitleKeys = ["publisher", "sourceType", "date"]
        }
        r.subtitle = subtitleKeys.map(text).filter { !$0.isEmpty }.joined(separator: " · ")
        let factKeys = [("siteType", "Site type"), ("siteFunction", "Site function"), ("siteIdentifier", "Site identifier"), ("countryName", "Country"), ("rank", "Rank"), ("period", "Period"), ("epoch", "Epoch"), ("ageRange", "Age range"), ("sourceType", "Source type"), ("publisher", "Publisher"), ("date", "Date"), ("pageRange", "Pages"), ("isbn", "ISBN")]
        r.facts = factKeys.compactMap { key, label in text(key).isEmpty ? nil : RecordFact(label: label, value: text(key)) }
        for (field, label) in [("dateRangeMin", "Date range min (BP)"), ("dateRangeMax", "Date range max (BP)")] {
            if let n = o[field]?.number { r.facts.append(RecordFact(label: label, value: n.formatted())) }
        }
        if let url = RecordLink.safeURL(o["url"]?.text) { r.externalLinks.append(.init(title: "Original source", url: url)) }
        if let url = RecordLink.safeURL(o["wikipediaUrl"]?.text) { r.externalLinks.append(.init(title: "Wikipedia", url: url)) }
        for link in HTMLContent.links(summaryHTML + text("longDescription"), baseURL: r.url) where !r.externalLinks.contains(where: { $0.url == link.url }) {
            r.externalLinks.append(link)
        }
        return r
    }
}
