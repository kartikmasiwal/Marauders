import SwiftUI

struct InteractiveMapView: View {
    let monument: Monument
    @ObservedObject var audioPlayer: AudioGuidePlayer
    @Binding var selectedTab: TourContainerView.TourTab
    @State private var selectedPoint: TourPoint?
    @State private var audioPoint: TourPoint?
    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Theme.surfaceContainer
                map(in: proxy.size)
                controls
                if let selectedPoint { pointCard(selectedPoint) }
            }
            .clipped()
        }
        .sheet(item: $audioPoint) { point in
            AudioPlayerSheet(monument: monument, point: point, player: audioPlayer)
        }
        .onAppear { selectedPoint = monument.points.first }
    }

    private func map(in size: CGSize) -> some View {
        ZStack {
            Image(monument.imageName)
                .resizable().scaledToFill()
                .frame(width: size.width, height: size.height)
                .clipped()
            ForEach(monument.points) { point in
                Button {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { selectedPoint = point }
                } label: {
                    VStack(spacing: 4) {
                        Text("\(point.number)")
                            .font(.caption.bold()).foregroundStyle(.white)
                            .frame(width: selectedPoint == point ? 38 : 30, height: selectedPoint == point ? 38 : 30)
                            .background(Theme.primary, in: Circle())
                            .overlay { Circle().stroke(.white, lineWidth: 3) }
                            .shadow(color: Theme.primary.opacity(0.45), radius: 8)
                        Text(point.title)
                            .font(.system(size: 9, weight: .bold)).foregroundStyle(Theme.primary)
                            .padding(.horizontal, 6).padding(.vertical, 3)
                            .background(Theme.surface.opacity(0.92), in: Capsule())
                    }
                }
                .position(x: size.width * point.position.x, y: size.height * point.position.y)
                .accessibilityIdentifier("mapPoint_\(point.id)")
            }
        }
        .scaleEffect(scale)
        .offset(offset)
        .gesture(
            MagnifyGesture()
                .onChanged { value in scale = min(max(lastScale * value.magnification, 1), 3.5) }
                .onEnded { _ in lastScale = scale; if scale == 1 { withAnimation { offset = .zero; lastOffset = .zero } } }
                .simultaneously(with: DragGesture().onChanged { value in
                    guard scale > 1 else { return }
                    offset = CGSize(width: lastOffset.width + value.translation.width, height: lastOffset.height + value.translation.height)
                }.onEnded { _ in lastOffset = offset })
        )
    }

    private var controls: some View {
        VStack(spacing: 8) {
            Button { zoom(by: 0.4) } label: { Image(systemName: "plus") }
            Divider().frame(width: 22)
            Button { zoom(by: -0.4) } label: { Image(systemName: "minus") }
            Button { withAnimation { scale = 1; lastScale = 1; offset = .zero; lastOffset = .zero } } label: { Image(systemName: "location.fill") }
        }
        .font(.headline).foregroundStyle(Theme.primary).padding(10)
        .background(.ultraThinMaterial, in: Capsule()).shadow(radius: 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
        .padding(.top, 18).padding(.trailing, 16)
    }

    private func pointCard(_ point: TourPoint) -> some View {
        VStack(alignment: .leading, spacing: 13) {
            Capsule().fill(Theme.mutedInk.opacity(0.22)).frame(width: 42, height: 5).frame(maxWidth: .infinity)
            Text("CHAPTER \(point.number) · \(point.subtitle.uppercased())")
                .font(.caption2.bold()).tracking(1).foregroundStyle(Theme.gold)
            Text(point.title).font(.system(size: 23, weight: .bold, design: .rounded)).foregroundStyle(Theme.ink)
            Text(point.details).font(.subheadline).foregroundStyle(Theme.mutedInk).lineLimit(3)
            HStack(spacing: 10) {
                Button { audioPoint = point } label: { Label("Listen", systemImage: "waveform.circle.fill").frame(maxWidth: .infinity) }
                    .buttonStyle(PrimaryButtonStyle())
                Button { selectedTab = .scan } label: {
                    Label("Live AR", systemImage: "viewfinder").font(.subheadline.bold()).foregroundStyle(Theme.primary)
                        .frame(maxWidth: .infinity).frame(height: 52)
                        .background(Theme.surfaceContainer, in: RoundedRectangle(cornerRadius: 15))
                        .overlay { RoundedRectangle(cornerRadius: 15).stroke(Theme.primary.opacity(0.25)) }
                }
            }
        }
        .padding(18).heritageCard()
        .frame(maxWidth: 520)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .padding(.horizontal, 16).padding(.bottom, 102)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    private func zoom(by delta: CGFloat) {
        withAnimation(.snappy) {
            scale = min(max(scale + delta, 1), 3.5)
            lastScale = scale
            if scale == 1 { offset = .zero; lastOffset = .zero }
        }
    }
}
