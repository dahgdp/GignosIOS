import SwiftUI

struct WebsiteMenu: View {
    @State private var showsAbout = false
    var body: some View {
        Menu("Gignos menu", systemImage: "line.3.horizontal") {
            Link("Home", destination: URL(string: "https://gignos.com")!)
            Section {
                Link("About", destination: URL(string: "https://gignos.com/about")!)
                Link("News", destination: URL(string: "https://gignos.com/news")!)
                Link("Contact", destination: URL(string: "https://gignos.com/contact")!)
            }
            Section("Help") {
                Link("Q&A", destination: URL(string: "https://gignos.com/qanda")!)
                Link("Privacy Policy", destination: URL(string: "https://gignos.com/privacy")!)
                Link("Email Gignos", destination: URL(string: "mailto:hello@gignos.com")!)
            }
            Button("About this app", systemImage: "info.circle") { showsAbout = true }
        }
        .sheet(isPresented: $showsAbout) { AboutView() }
    }
}
