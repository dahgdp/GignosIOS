import MapKit
import SwiftUI

struct AtlasView: View {
    let records: [CatalogRecord]
    @State private var position: MapCameraPosition = .automatic
    @State private var selectedID: String?
    @State private var showsList = false
    private var mapped: [CatalogRecord] { records.filter(\.hasCoordinate) }
    private var selected: CatalogRecord? { mapped.first { $0.id == selectedID } }

    var body: some View {
        Map(position: $position, selection: $selectedID) {
            ForEach(mapped) { record in
                if let coordinate = record.coordinate {
                    Marker(record.title, coordinate: coordinate).tint(Color.gignos).tag(record.id)
                }
            }
        }
        .mapStyle(.standard(elevation: .realistic, pointsOfInterest: .excludingAll))
        .mapControls { MapCompass(); MapScaleView() }
        .safeAreaInset(edge: .bottom) {
            if let record = selected {
                HStack(alignment: .top) {
                    NavigationLink { RecordDetailView(initial: record) } label: {
                        VStack(alignment: .leading, spacing: 5) {
                            Text(record.title).font(.headline)
                            Text(record.subtitle).font(.subheadline).foregroundStyle(.secondary)
                            Label("Explore site", systemImage: "arrow.right").font(.subheadline.weight(.semibold)).padding(.top, 4)
                        }.frame(maxWidth: .infinity, alignment: .leading)
                    }.buttonStyle(.plain)
                    Button("Close selection", systemImage: "xmark.circle.fill") { selectedID = nil }
                        .font(.title2).foregroundStyle(.secondary).frame(minWidth: 44, minHeight: 44)
                }.padding(20).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24)).padding()
            } else {
                Text("\(mapped.count) of \(records.count) sites have coordinates")
                    .font(.footnote.weight(.medium)).padding(12).background(.regularMaterial, in: Capsule()).padding()
            }
        }
        .navigationTitle("Map").navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) { Button("Show all sites", systemImage: "globe") { position = .automatic; selectedID = nil } }
            ToolbarItem(placement: .topBarTrailing) { Button("List map sites", systemImage: "list.bullet") { showsList = true } }
        }
        .sheet(isPresented: $showsList) {
            NavigationStack {
                List(mapped) { record in
                    NavigationLink { RecordDetailView(initial: record) } label: { RecordRow(record: record) }
                }
                .navigationTitle("Map sites").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { showsList = false } } }
            }
        }
    }
}
