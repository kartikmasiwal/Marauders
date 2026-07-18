import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            BookingsView()
                .tabItem { Label("My Tours", systemImage: "ticket.fill") }

            ExploreView()
                .tabItem { Label("Explore", systemImage: "map.fill") }

            ProfileView()
                .tabItem { Label("Profile", systemImage: "person.crop.circle") }
        }
        .tint(Theme.primary)
    }
}
