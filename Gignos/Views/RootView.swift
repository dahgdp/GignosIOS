import SwiftUI

struct RootView: View {
    @State private var selectedSection = WebsiteSection.sites

    var body: some View {
        TabView(selection: $selectedSection) {
            ForEach(WebsiteSection.allCases) { section in
                Tab(section.title, systemImage: section.symbol, value: section) {
                    NavigationStack {
                        CatalogView(section: section)
                    }
                }
            }
        }
        .tabViewStyle(.sidebarAdaptable)
    }
}

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Label("Gignos", systemImage: "globe.europe.africa.fill")
                        .font(.largeTitle.bold()).foregroundStyle(Color.gignos)
                    Text("A field guide to human origins.")
                        .font(.title3).foregroundStyle(.secondary)
                }
                Section("Connected to Gignos") {
                    Text("Catalogs and detail pages load directly from the public Gignos API. Pull down on a catalog to refresh it.")
                    Text("Saved records stay on this device. Their saved text is available offline; fresh details, maps, and source pages require an internet connection.")
                }
                Section("Explore more") {
                    Link("Visit Gignos", destination: URL(string: "https://gignos.com")!)
                    Link("About the project", destination: URL(string: "https://gignos.com/about")!)
                }
            }
            .navigationTitle("About")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }
}
