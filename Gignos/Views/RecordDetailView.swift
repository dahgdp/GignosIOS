import MapKit
import SwiftUI

extension CatalogRecord {
    var coordinate: CLLocationCoordinate2D? {
        guard hasCoordinate, let latitude, let longitude else { return nil }
        return .init(latitude: latitude, longitude: longitude)
    }
}

struct RecordDetailView: View {
    let initial: CatalogRecord
    @Environment(LibraryStore.self) private var library
    @State private var detail: RecordDetail?
    @State private var isLoading = false
    @State private var error: String?
    private var record: CatalogRecord { detail?.record ?? initial }

    var body: some View {
        List {
            if let error {
                Section {
                    Label("Couldn’t refresh details", systemImage: "wifi.exclamationmark").font(.headline)
                    Text(error).font(.subheadline)
                    Text("Showing previously loaded text. Related records may be unavailable.").font(.caption).foregroundStyle(.secondary)
                    Button("Try again") { Task { await load() } }
                }
            }
            if isLoading { ProgressView("Loading details…") }
            Section {
                if let coordinate = record.coordinate {
                    Map(initialPosition: .region(MKCoordinateRegion(center: coordinate, span: .init(latitudeDelta: 3, longitudeDelta: 3))), interactionModes: []) {
                        Marker(record.title, coordinate: coordinate).tint(Color.gignos)
                    }.frame(height: 210).listRowInsets(EdgeInsets())
                        .accessibilityLabel("Map showing the catalog location of \(record.title)")
                }
                VStack(alignment: .leading, spacing: 12) {
                    Text(record.section.title).font(.caption.weight(.semibold)).foregroundStyle(Color.gignos)
                    Text(record.title).font(.system(.largeTitle, design: .serif).weight(.medium))
                    if !record.subtitle.isEmpty { Text(record.subtitle).foregroundStyle(.secondary) }
                }.padding(.vertical, 8)
            }
            if record.wikipediaDerived {
                Section { Label("Wikipedia-derived content. Gignos marks this material as not reviewed by its research team.", systemImage: "text.book.closed").font(.subheadline).foregroundStyle(.secondary) }
            }
            if !record.summary.isEmpty {
                Section("Overview") { Text(record.summary).lineSpacing(5).textSelection(.enabled) }
            }
            if !record.facts.isEmpty {
                Section("Details") {
                    ForEach(record.facts, id: \.label) { fact in LabeledContent(fact.label, value: fact.value) }
                }
            }
            if !record.body.isEmpty {
                Section("Description") { Text(record.body).lineSpacing(5).textSelection(.enabled) }
            }
            if let detail {
                ForEach(detail.groups) { group in
                    Section(group.title) {
                        ForEach(group.records) { related in
                            NavigationLink { RecordDetailView(initial: related) } label: { RecordRow(record: related) }
                        }
                    }
                }
            }
            if !record.externalLinks.isEmpty {
                Section("References & links") {
                    ForEach(record.externalLinks) { link in Link(link.title, destination: link.url) }
                }
            }
            Section {
                Link(destination: record.url) { Label("Full entry on Gignos", systemImage: "arrow.up.right.square") }
            } footer: {
                Text("Loaded from Gignos. Full media and original page formatting are available on the website. Catalog coordinates are not directions to the site.")
            }
        }
        .accessibilityIdentifier("detail-\(record.id)")
        .navigationTitle(record.title).navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) { SaveButton(record: record) }
            ToolbarItem(placement: .topBarTrailing) { ShareLink(item: record.url) }
        }
        .task(id: initial.id) { await load() }
        .refreshable { await load() }
    }

    private func load() async {
        guard !isLoading else { return }
        isLoading = true
        error = nil
        defer { isLoading = false }
        // Show the cached copy instantly, then refresh from the network.
        if detail == nil, let cached = try? await AppDatabase.shared.cachedDetail(initial) { detail = cached }
        do {
            let fetched = try await GignosAPI().detail(initial)
            try Task.checkCancellation()
            detail = fetched
            library.update(fetched.record)
            try? await AppDatabase.shared.store(fetched)
        } catch is CancellationError {
        } catch let failure as URLError where failure.code == .cancelled {
        } catch { self.error = error.localizedDescription }
    }
}

struct SavedView: View {
    @Environment(LibraryStore.self) private var library
    @State private var query = ""
    private var results: [CatalogRecord] { library.saved.filter { $0.matches(query) } }
    var body: some View {
        List {
            if let error = library.error { Text(error).foregroundStyle(.red) }
            if library.saved.isEmpty {
                ContentUnavailableView("Your next discoveries", systemImage: "bookmark", description: Text("Save records from any section to keep their text here for later."))
            } else {
                ForEach(results) { record in
                    NavigationLink { RecordDetailView(initial: record) } label: { RecordRow(record: record) }
                        .accessibilityIdentifier("saved-\(record.id)")
                        .swipeActions { SaveButton(record: record) }
                }
                if results.isEmpty { ContentUnavailableView.search(text: query) }
            }
        }
        .navigationTitle("Saved records")
        .searchable(text: $query, prompt: "Search saved records")
    }
}
