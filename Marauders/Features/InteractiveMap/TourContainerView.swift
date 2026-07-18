import SwiftData
import SwiftUI

struct TourContainerView: View {
    let booking: TourBooking
    @StateObject private var session: TourSession
    @StateObject private var audioPlayer = NuggetAudioPlayer()
    @StateObject private var locationService = LocationService()
    @Environment(\.modelContext) private var modelContext
    @Query private var allVisits: [VisitedNugget]
    @State private var tab: TourTab = .map
    @State private var showBrowse = false

    enum TourTab: String, CaseIterable {
        case map = "Map"
        case scan = "Scan"
        case info = "Info"

        var icon: String {
            switch self { case .map: "map.fill"; case .scan: "viewfinder"; case .info: "info.circle.fill" }
        }
    }

    init(booking: TourBooking, installed: InstalledTour, language: String) {
        self.booking = booking
        _session = StateObject(wrappedValue: TourSession(installed: installed, language: language))
    }

    private var visits: [VisitedNugget] {
        allVisits.filter { $0.monumentId == session.installed.package.monument.id }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                switch tab {
                case .map:
                    InteractiveMapView(session: session, visitedNuggetIDs: Set(visits.map(\.id)), selectedTab: $tab, onBrowse: { showBrowse = true })
                case .scan:
                    ARCameraView(session: session, audioPlayer: audioPlayer, onBrowse: { showBrowse = true })
                case .info:
                    MonumentInfoView(session: session, audioPlayer: audioPlayer, visitedCount: visits.count)
                }
            }
            tourBar
        }
        .ignoresSafeArea(edges: .bottom)
        .navigationTitle(session.installed.package.monument.name.v(session.language))
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
        .fullScreenCover(isPresented: $showBrowse) {
            BrowseModeView(session: session, onEngage: engage)
        }
        .onAppear {
            audioPlayer.onStart = markVisited
            locationService.start()
        }
        .onDisappear {
            audioPlayer.stop()
            locationService.stop()
        }
        .onChange(of: locationService.location) { _, _ in
            if let checkpoint = locationService.nearestCheckpoint(in: session.installed.package.checkpoints) {
                withAnimation { session.select(checkpoint: checkpoint) }
            }
        }
    }

    private var tourBar: some View {
        HStack {
            ForEach(TourTab.allCases, id: \.self) { item in
                Button { withAnimation(.snappy) { tab = item } } label: {
                    VStack(spacing: 4) {
                        Image(systemName: item.icon).font(.system(size: 20, weight: .semibold))
                        Text(item.rawValue.uppercased()).font(.system(size: 10, weight: .bold)).tracking(0.7)
                    }
                    .foregroundStyle(tab == item ? Theme.primary : Theme.mutedInk.opacity(0.7))
                    .frame(maxWidth: .infinity).padding(.vertical, 9)
                    .background(tab == item ? Theme.goldLight.opacity(0.28) : .clear, in: Capsule())
                }
                .accessibilityIdentifier("tourTab_\(item.rawValue.lowercased())")
            }
        }
        .padding(.horizontal, 14).padding(.top, 8).padding(.bottom, 24)
        .background(.ultraThinMaterial)
        .clipShape(UnevenRoundedRectangle(topLeadingRadius: 22, topTrailingRadius: 22))
        .shadow(color: .black.opacity(0.1), radius: 12, y: -3)
    }

    private func markVisited(_ nuggetID: String) {
        guard !visits.contains(where: { $0.id == nuggetID }),
              let checkpoint = session.checkpoint(containing: nuggetID) else { return }
        session.activeNuggetID = nuggetID
        session.currentCheckpointID = checkpoint.id
        modelContext.insert(VisitedNugget(
            id: nuggetID,
            checkpointId: checkpoint.id,
            monumentId: session.installed.package.monument.id
        ))
        try? modelContext.save()
    }

    private func engage(_ checkpoint: Checkpoint, _ nugget: Nugget) {
        session.select(checkpoint: checkpoint, nugget: nugget)
        audioPlayer.replay(nugget: nugget, language: session.language, directory: session.installed.directory)
    }
}
