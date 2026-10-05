import Foundation

// Keep these labels, order, and paths aligned with the website's primary navigation.
enum WebsiteSection: String, CaseIterable, Identifiable, Hashable, Codable, Sendable {
    case sites, classifications, timePeriods = "time_periods", cultures, sources
    var id: String { rawValue }
    var title: String {
        switch self {
        case .sites: "Sites"
        case .classifications: "Classifications"
        case .timePeriods: "Time periods"
        case .cultures: "Cultures"
        case .sources: "Sources"
        }
    }
    var symbol: String {
        switch self {
        case .sites: "globe.europe.africa.fill"
        case .classifications: "point.3.connected.trianglepath.dotted"
        case .timePeriods: "clock.fill"
        case .cultures: "building.columns.fill"
        case .sources: "books.vertical.fill"
        }
    }
    var url: URL { URL(string: "https://gignos.com/\(rawValue)")! }
    var subtitle: String {
        switch self {
        case .sites: "Explore the places that preserve our past."
        case .classifications: "Explore the branches of the human family."
        case .timePeriods: "Place discoveries in geological time."
        case .cultures: "Explore the cultures in the Gignos catalog."
        case .sources: "Follow the evidence behind each discovery."
        }
    }
}
