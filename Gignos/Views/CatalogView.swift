import SwiftUI

struct CatalogView: View {
    @Environment(LibraryStore.self) private var library
    @State private var store: SectionStore
    @State private var filter = CatalogFilter()
    @State private var showsFilters = false
    init(section: WebsiteSection) { _store = State(initialValue: SectionStore(section: section)) }

    var body: some View {
        List {
            if store.section == .sites {
                Section {
                    NavigationLink { AtlasView(records: store.results) } label: { Label("Map", systemImage: "map") }
                        .disabled(!store.hasContent)
                    NavigationLink { SavedView() } label: { Label("Saved records", systemImage: "bookmark") }
                }
            }
            if let error = store.error {
                Section {
                    Label(store.hasContent ? "Refresh failed" : "Couldn’t load catalog", systemImage: "wifi.exclamationmark").font(.headline)
                    Text(error).font(.subheadline).foregroundStyle(.secondary)
                    if store.hasContent { Text("Showing the copy saved on this device.").font(.caption) }
                    Button("Try again") { Task { await store.sync() } }.disabled(store.isSyncing)
                }
            }
            if store.isSyncing && !store.isComplete {
                Section {
                    ProgressView("Loading \(store.section.title.lowercased())…")
                    if store.expectedCount > 0 {
                        ProgressView(value: Double(store.syncedCount), total: Double(max(1, store.expectedCount)))
                        Text("\(store.syncedCount) of \(store.expectedCount) records")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            if store.hasContent {
                if filter.query.isEmpty && !filter.isActive {
                    Section {
                        VStack(alignment: .leading, spacing: 12) {
                            Label("GIGNOS", systemImage: store.section.symbol).font(.caption.weight(.semibold)).tracking(2)
                            Text(store.section.subtitle).font(.system(.title2, design: .serif))
                            Text(store.isComplete ? "\(store.cachedCount) records" : "\(store.cachedCount) of \(store.expectedCount) records so far")
                                .font(.caption).foregroundStyle(.secondary)
                                // UI tests wait on this, so it only appears once search covers everything.
                                .accessibilityIdentifier(store.isComplete ? "catalog-ready-\(store.section.rawValue)" : "catalog-syncing-\(store.section.rawValue)")
                        }.padding(.vertical, 8)
                    }.listRowBackground(Color.gignos.opacity(0.07))
                }
                if !store.isComplete && (!filter.query.isEmpty || filter.isActive) {
                    Section {
                        Label("Still downloading. Results cover \(store.cachedCount) of \(store.expectedCount) records.", systemImage: "arrow.down.circle")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                }
                Section {
                    ForEach(store.results) { record in
                        NavigationLink { RecordDetailView(initial: record) } label: { RecordRow(record: record) }
                            .accessibilityIdentifier("record-\(record.id)")
                            .swipeActions { SaveButton(record: record) }
                            .contextMenu { SaveButton(record: record); ShareLink(item: record.url) }
                    }
                    if store.results.isEmpty {
                        ContentUnavailableView.search(text: filter.query)
                        if filter.isActive { Button("Clear filters") { filter.kind = "All types"; filter.country = "All countries" } }
                    }
                } header: {
                    HStack { Text(store.section.title); Spacer(); Text(store.isComplete ? store.results.count.formatted() : "\(store.results.count)+") }
                } footer: {
                    if let date = store.lastSynced { Text("Updated \(date.formatted(.relative(presentation: .named))). Pull down to refresh.") }
                }
            }
            Section {
                Link(destination: store.section.url) { Label("View on Gignos", systemImage: "arrow.up.right.square") }
            }
        }
        .navigationTitle(store.section.title)
        .searchable(text: $filter.query, placement: .navigationBarDrawer(displayMode: .always), prompt: store.section == .sites ? "Sites, countries, discoveries" : "Search \(store.section.title.lowercased())")
        .task {
            await store.load()
            if store.isComplete && filter == CatalogFilter() { library.migratePreviewBookmarks(from: store.results) }
        }
        .task(id: filter) {
            do { try await Task.sleep(for: .milliseconds(150)) } catch { return }   // debounce typing
            await store.apply(filter)
        }
        .refreshable { await store.sync() }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) { WebsiteMenu() }
            if store.section == .sites {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Filter sites", systemImage: filter.isActive ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle") { showsFilters = true }
                        .disabled(!store.hasContent)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu("Sort sites", systemImage: "arrow.up.arrow.down") {
                        Picker("Sort by", selection: $filter.sort) { ForEach(CatalogSort.allCases) { Text($0.rawValue).tag($0) } }
                    }
                }
            }
        }
        .sheet(isPresented: $showsFilters) { FilterView(filter: $filter, facets: store.facets) }
    }
}

struct FilterView: View {
    @Binding var filter: CatalogFilter
    let facets: CatalogFacets
    @Environment(\.dismiss) private var dismiss
    @State private var kind = "All types"
    @State private var country = "All countries"
    var body: some View {
        NavigationStack {
            Form {
                Section("Narrow your exploration") {
                    Picker("Site type", selection: $kind) {
                        Text("All types").tag("All types")
                        ForEach(facets.kinds, id: \.self) { Text($0).tag($0) }
                    }
                    Picker("Country", selection: $country) {
                        Text("All countries").tag("All countries")
                        ForEach(facets.countries, id: \.self) { Text($0).tag($0) }
                    }
                }
                Button("Reset filters") { kind = "All types"; country = "All countries" }
            }
            .navigationTitle("Filters").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Apply") { filter.kind = kind; filter.country = country; dismiss() } }
            }
        }
        .onAppear { kind = filter.kind; country = filter.country }
        .presentationDetents([.medium, .large])
    }
}

struct RecordRow: View {
    let record: CatalogRecord
    @Environment(LibraryStore.self) private var library
    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: record.section == .sites ? "mountain.2.fill" : record.section.symbol)
                .font(.title3).foregroundStyle(Color.gignos).frame(width: 44, height: 44)
                .background(Color.gignos.opacity(0.09), in: RoundedRectangle(cornerRadius: 12)).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 5) {
                Text(record.title).font(.headline)
                if !record.subtitle.isEmpty { Text(record.subtitle).font(.subheadline).foregroundStyle(.secondary) }
            }
            Spacer(minLength: 0)
            if library.contains(record) { Image(systemName: "bookmark.fill").font(.caption).foregroundStyle(Color.gignos).accessibilityLabel("Saved") }
        }.padding(.vertical, 8).accessibilityElement(children: .combine)
    }
}

struct SaveButton: View {
    let record: CatalogRecord
    @Environment(LibraryStore.self) private var library
    var body: some View {
        Button(library.contains(record) ? "Remove from saved" : "Save record", systemImage: library.contains(record) ? "bookmark.slash" : "bookmark") { library.toggle(record) }
            .tint(Color.gignos)
            .accessibilityIdentifier("save-record")
    }
}
