import SwiftUI

struct TourContainerView: View {
    let monument: Monument
    @State private var tab: TourTab = .map
    @StateObject private var audioPlayer = AudioGuidePlayer()

    enum TourTab: String, CaseIterable {
        case map = "Map"
        case scan = "Scan"
        case info = "Info"

        var icon: String {
            switch self { case .map: "map.fill"; case .scan: "viewfinder"; case .info: "info.circle.fill" }
        }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                switch tab {
                case .map: InteractiveMapView(monument: monument, audioPlayer: audioPlayer, selectedTab: $tab)
                case .scan: ARCameraView(monument: monument)
                case .info: MonumentInfoView(monument: monument, audioPlayer: audioPlayer)
                }
            }
            tourBar
        }
        .ignoresSafeArea(edges: .bottom)
        .navigationTitle(monument.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
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
}
