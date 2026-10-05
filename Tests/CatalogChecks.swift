import Foundation

actor FakeAPI: CatalogServing {
    var shouldFail = false
    var delay: UInt64 = 0
    var duplicate = false
    func configure(fail: Bool = false, delay: UInt64 = 0, duplicate: Bool = false) {
        shouldFail = fail; self.delay = delay; self.duplicate = duplicate
    }
    func page(_ section: WebsiteSection, number: Int) async throws -> CatalogPage {
        if delay > 0 { try await Task.sleep(nanoseconds: delay) }
        if shouldFail && number == 2 { throw APIError.http(503) }
        let r = CatalogRecord(section: section, key: duplicate ? "same" : "record-\(number)", title: "Record \(number)")
        return CatalogPage(records: [r], page: number, total: 3, totalPages: 3)
    }
    func detail(_ record: CatalogRecord) async throws -> RecordDetail { .init(record: record, groups: []) }
}

final class StubURLProtocol: URLProtocol, @unchecked Sendable {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        let response = HTTPURLResponse(url: request.url!, statusCode: 503, httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

@main
struct CatalogChecks {
    @MainActor static func main() async throws {
        func data(_ s: String) -> Data { Data(s.utf8) }
        let sites = try GignosAPI.decodePage(data("""
        [[{"slug":"cave-one","name":" Café Cave ","countryName":"Italy","siteType":"Cave","latitude":null,"longitude":null,"showWikipediaDesc":true,"wikipediaDescription":"<p>A &amp; B &eacute; &#x1F30D;</p>","shortDescription":"do not select"}],{"page":"1","total":1,"total_pages":1}]
        """), section: .sites)
        precondition(sites.page == 1 && sites.records.count == 1)
        let record = sites.records[0]
        precondition(record.title == "Café Cave")
        precondition(record.summary == "A & B é 🌍" && !record.hasCoordinate)
        precondition(record.wikipediaDerived && record.url.path == "/sites/cave-one")
        precondition(record.matches("cafe italy"))
        var filter = CatalogFilter()
        filter.kind = "Cave"; filter.country = "Turkey"
        precondition(filter.apply(to: sites.records).isEmpty)
        filter.country = "Italy"
        precondition(filter.apply(to: sites.records).count == 1)
        let detail = try GignosAPI.decodeDetail(data("""
        [{"id":1227,"slug":"not-the-route","title":"A source","url":"javascript:alert(1)"},{"relatedObjects":{"sites":[{"slug":"laetoli","name":"Laetoli","siteType":8,"latitude":-2.99,"longitude":35.35}],"timePeriods":[{"slug":"ionian","age":"Chibanian"}]}}]
        """), section: .sources)
        precondition(detail.record.url.path == "/sources/1227")
        precondition(detail.record.externalLinks.isEmpty)
        precondition(detail.groups.count == 2 && detail.groups[0].records[0].kind.isEmpty)
        precondition(detail.groups[0].records[0].hasCoordinate)
        precondition(detail.groups[1].records[0].url.path == "/time_periods/ionian")
        for invalid in ["[]", "{}", "[[{}],{\"page\":1,\"total\":1,\"total_pages\":1}]", "[[],{\"page\":1,\"total\":0,\"total_pages\":9999}]"] {
            do { _ = try GignosAPI.decodePage(data(invalid), section: .sites); fatalError("Accepted invalid envelope") } catch {}
        }
        let empty = try GignosAPI.decodePage(data("[[],{\"page\":1,\"total\":0,\"total_pages\":0}]"), section: .sites)
        precondition(empty.records.isEmpty)
        precondition(HTMLContent.plainText("<script>bad()</script><p>one</p><p>two &lt; three</p>") == "one\n\ntwo < three")
        let links = HTMLContent.links("<a href='#ref'>[1]</a><a href='javascript:alert(1)'>Bad</a>", baseURL: record.url)
        precondition(links.count == 1 && links[0].url.absoluteString == record.url.absoluteString + "#ref")
        precondition(WebsiteSection.allCases.map(\.rawValue) == ["sites", "classifications", "time_periods", "cultures", "sources"])

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        do {
            _ = try await GignosAPI(session: URLSession(configuration: configuration)).page(.sites, number: 1)
            fatalError("Expected HTTP failure")
        } catch APIError.http(let code) { precondition(code == 503) }

        let api = FakeAPI()
        let store = CatalogStore(section: .sites, api: api)
        await store.reload()
        precondition(store.hasLoaded && store.records.count == 3 && store.loadedCount == 3 && !store.isLoading)
        let original = store.records
        await api.configure(fail: true)
        await store.reload()
        precondition(store.error != nil && store.records == original)
        await api.configure(duplicate: true)
        await store.reload()
        precondition(store.error != nil && store.records == original)
        await api.configure(delay: 100_000_000)
        let task = Task { await store.reload() }
        try await Task.sleep(nanoseconds: 20_000_000)
        task.cancel()
        await task.value
        precondition(!store.isLoading && store.error == nil && store.records == original)

        let suite = "GignosChecks.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let library = LibraryStore(defaults: defaults)
        library.toggle(record)
        let restored = LibraryStore(defaults: defaults)
        precondition(restored.contains(record) && restored.saved[0].summary == record.summary)
        restored.toggle(record)
        precondition(LibraryStore(defaults: defaults).saved.isEmpty)
        defaults.set(["cave-one", "not-yet-resolved"], forKey: "gignos.savedSiteIDs")
        restored.migratePreviewBookmarks(from: [record])
        restored.migratePreviewBookmarks(from: [record])
        precondition(restored.saved.count == 1 && restored.contains(record))
        precondition(defaults.stringArray(forKey: "gignos.savedSiteIDs") == ["not-yet-resolved"])
        print("PASS: API envelopes, optional fields, numeric relationships, canonical URLs, HTML/entities/links, filters, HTTP errors, pagination, atomic refresh, cancellation, bookmark persistence.")

        if CommandLine.arguments.contains("--live") || CommandLine.arguments.contains("--live-sources") {
            for section in (CommandLine.arguments.contains("--live-sources") ? [.sources] : WebsiteSection.allCases) {
                let live = CatalogStore(section: section)
                await live.reload()
                guard live.hasLoaded, live.error == nil, !live.records.isEmpty else {
                    throw NSError(domain: "LiveChecks", code: 1, userInfo: [NSLocalizedDescriptionKey: "\(section.title): \(live.error ?? "No records")"])
                }
                _ = try await GignosAPI().detail(live.records[0])
                print("LIVE PASS: \(section.title): \(live.records.count) records, all pages + detail")
            }
            let laetoli = try await GignosAPI().detail(CatalogRecord(section: .sites, key: "laetoli-site-g", title: "Laetoli Site G"))
            precondition(laetoli.groups.contains { $0.title == "Cited sources" && !$0.records.isEmpty })
            let source = try await GignosAPI().detail(CatalogRecord(section: .sources, key: "1227", title: "Source"))
            precondition(source.groups.contains { $0.title == "Sites" && $0.records.contains { $0.key == "laetoli-site-g" } })
            print("LIVE PASS: Laetoli → cited sources → source 1227 → Laetoli relationship")
        }
    }
}
