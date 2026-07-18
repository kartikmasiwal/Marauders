import SwiftUI
import SwiftData

@main
struct MaraudersApp: App {
    @State private var session = AppSession()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(session)
                .preferredColorScheme(.light)
                .modelContainer(for: VisitedNugget.self)
        }
    }
}
