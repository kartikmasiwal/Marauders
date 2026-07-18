import SwiftUI

struct ProfileView: View {
    @Environment(AppSession.self) private var session

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 16) {
                        Image(systemName: "person.crop.circle.fill").font(.system(size: 54)).foregroundStyle(Theme.primary)
                        VStack(alignment: .leading) {
                            Text("Demo Explorer").font(.headline)
                            Text(session.userPhone.isEmpty ? "+91 98765 43210" : session.userPhone).foregroundStyle(Theme.mutedInk)
                        }
                    }.padding(.vertical, 8)
                }
                Section("TOUR PREFERENCES") {
                    Label("English audio", systemImage: "waveform")
                    Label("Downloads", systemImage: "arrow.down.circle")
                    Label("Accessibility", systemImage: "accessibility")
                }
                Section {
                    Button("Sign Out", role: .destructive) { session.signOut() }
                        .accessibilityIdentifier("signOutButton")
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.surfaceLow)
            .navigationTitle("Profile")
        }
    }
}
