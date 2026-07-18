import SwiftData
import SwiftUI

struct TourContainerView: View {
    let booking: TourBooking
    @StateObject private var session: TourSession
    @StateObject private var audioPlayer = NuggetAudioPlayer()
    @StateObject private var locationService = LocationService()
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query private var allVisits: [VisitedNugget]
    @State private var tab: TourTab = .map
    @State private var showBrowse = false
    @State private var showGiftMessage = false

    enum TourTab: String, CaseIterable {
        case map = "Map"
        case scan = "AR Exp"
        case info = "Info"

        var icon: String {
            switch self { case .map: "map.fill"; case .scan: "viewfinder"; case .info: "info.circle.fill" }
        }

        var accessibilityID: String {
            switch self { case .map: "map"; case .scan: "scan"; case .info: "info" }
        }

        var localizedTitle: LocalizedStringKey {
            switch self { case .map: "Map"; case .scan: "AR Exp"; case .info: "Info" }
        }
    }

    init(booking: TourBooking, installed: InstalledTour, language: String) {
        self.booking = booking
        _session = StateObject(wrappedValue: TourSession(installed: installed, language: language))
    }

    private var visits: [VisitedNugget] {
        allVisits.filter { $0.monumentId == session.installed.package.monument.id }
    }

    private var totalNuggets: Int {
        session.installed.package.checkpoints.reduce(0) { $0 + $1.nuggets.count }
    }

    private var isJourneyComplete: Bool {
        totalNuggets > 0 && visits.count >= totalNuggets
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
                    MonumentInfoView(session: session, audioPlayer: audioPlayer, visitedNuggetIDs: Set(visits.map(\.id)))
                }
            }
            tourBar
        }
        .ignoresSafeArea(edges: .bottom)
        .safeAreaInset(edge: .top, spacing: 0) { tripProgress }
        .navigationTitle(session.installed.package.monument.name.v(session.language))
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
        .fullScreenCover(isPresented: $showBrowse) {
            BrowseModeView(session: session, onEngage: engage)
        }
        .alert(isJourneyComplete ? "Gift card unlocked" : "Gift locked", isPresented: $showGiftMessage) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(isJourneyComplete ? "Journey complete. Your gift card is ready to unlock." : "Complete the journey to unlock the gift card.")
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
                withAnimation(Motion.change(reduceMotion: reduceMotion)) { session.select(checkpoint: checkpoint) }
            }
        }
    }

    private var tripProgress: some View {
        let completed = min(visits.count, totalNuggets)
        let progress = totalNuggets == 0 ? 0 : Double(completed) / Double(totalNuggets)

        return VStack(spacing: 8) {
            HStack {
                Label("TRIP PROGRESS", systemImage: "figure.walk")
                    .font(.caption.bold()).tracking(0.8)
                    .foregroundStyle(Theme.primary)
                Spacer()
                Text("\(completed) of \(totalNuggets) secrets - \(Int(progress * 100))%")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.mutedInk)
                    .contentTransition(.numericText())
                    .animation(reduceMotion ? nil : Motion.standard, value: completed)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Trip progress")
            .accessibilityValue("\(completed) of \(totalNuggets) secrets discovered, \(Int(progress * 100)) percent")

            ZStack(alignment: .trailing) {
                ProgressView(value: progress)
                    .tint(Theme.gold)
                    .scaleEffect(y: 1.6)
                    .padding(.trailing, 16)
                    .animation(reduceMotion ? nil : Motion.standard, value: progress)
                    .accessibilityHidden(true)
                Button { showGiftMessage = true } label: {
                    Image(systemName: isJourneyComplete ? "gift.fill" : "gift")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(isJourneyComplete ? Theme.primary : Theme.mutedInk)
                        .frame(width: 34, height: 34)
                        .background(isJourneyComplete ? Theme.goldLight : Theme.surfaceContainer, in: Circle())
                        .overlay { Circle().stroke(Theme.gold.opacity(isJourneyComplete ? 0.85 : 0.35), lineWidth: 1.5) }
                }
                .buttonStyle(SubtlePressButtonStyle())
                .animation(reduceMotion ? nil : Motion.quick, value: isJourneyComplete)
                .accessibilityLabel(isJourneyComplete ? "Gift card unlocked" : "Gift card locked")
                .accessibilityHint(isJourneyComplete ? "Shows your unlocked reward" : "Shows how to unlock the reward")
            }
        }
        .padding(.horizontal, 20).padding(.vertical, 12)
        .background(.ultraThinMaterial)
        .overlay(alignment: .bottom) { Divider().opacity(0.45) }
    }

    private var tourBar: some View {
        HStack {
            ForEach(TourTab.allCases, id: \.self) { item in
                Button { tab = item } label: {
                    VStack(spacing: 4) {
                        Image(systemName: item.icon).font(.system(size: 20, weight: .semibold))
                        Text(item.localizedTitle).font(.system(size: 10, weight: .bold)).tracking(0.7).textCase(.uppercase)
                    }
                    .foregroundStyle(tab == item ? Theme.primary : Theme.mutedInk.opacity(0.7))
                    .frame(maxWidth: .infinity).padding(.vertical, 9)
                    .background(tab == item ? Theme.goldLight.opacity(0.28) : .clear, in: Capsule())
                    .animation(reduceMotion ? nil : Motion.quick, value: tab)
                }
                .accessibilityIdentifier("tourTab_\(item.accessibilityID)")
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
