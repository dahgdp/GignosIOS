import SwiftUI

@main
struct GignosApp: App {
    @State private var library: LibraryStore

    init() {
        #if DEBUG
        if let suite = ProcessInfo.processInfo.environment["GIGNOS_UI_TEST_DEFAULTS"],
           let defaults = UserDefaults(suiteName: suite) {
            _library = State(initialValue: LibraryStore(defaults: defaults))
            return
        }
        #endif
        _library = State(initialValue: LibraryStore())
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(library)
                .tint(Color.gignos)
        }
    }
}

extension Color {
    static let gignos = Color("AccentColor")
}
