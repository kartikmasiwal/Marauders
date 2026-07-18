import SwiftUI

struct InteractiveMapView: View {
    @ObservedObject var session: TourSession
    let visitedNuggetIDs: Set<String>
    @Binding var selectedTab: TourContainerView.TourTab
    let onBrowse: () -> Void
    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var isCheckpointCardPresented = true

    private var ordered: [Checkpoint] { session.installed.package.checkpoints.sorted { $0.order < $1.order } }

    var body: some View {
        GeometryReader { proxy in
            let mapSize = fittedMapSize(in: proxy.size)
            ZStack {
                Theme.surfaceContainer.ignoresSafeArea()
                ZStack {
                    Image(mapImageName)
                        .resizable().scaledToFit().frame(width: mapSize.width, height: mapSize.height)
                    trail(in: mapSize)
                    checkpoints(in: mapSize)
                }
                .frame(width: mapSize.width, height: mapSize.height)
                .scaleEffect(scale).offset(offset)
                .gesture(mapGesture)
                controls
                checkpointCard
            }
            .clipped()
        }
    }

    private var mapImageName: String {
        switch session.installed.package.monument.id {
        case "national_war_memorial": "WarMemorialMap"
        case "zomato_farmhouse": "ZomatoFarmMap"
        default: "TajMahalMap"
        }
    }

    private func trail(in size: CGSize) -> some View {
        Canvas { context, _ in
            var path = Path()
            for (index, checkpoint) in ordered.enumerated() {
                let point = CGPoint(x: size.width * checkpoint.mapPosition.x, y: size.height * checkpoint.mapPosition.y)
                index == 0 ? path.move(to: point) : path.addLine(to: point)
            }
            context.stroke(path, with: .color(Theme.gold.opacity(0.72)), style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round, dash: [6, 8]))
        }
        .frame(width: size.width, height: size.height)
        .allowsHitTesting(false)
    }

    private func checkpoints(in size: CGSize) -> some View {
        ZStack {
            ForEach(Array(ordered.enumerated()), id: \.element.id) { index, checkpoint in
                let state = checkpointState(checkpoint, index: index)
                Button { select(checkpoint, state: state) } label: {
                    VStack(spacing: 4) {
                        ZStack {
                            Circle().fill(state.color).frame(width: state == .current ? 42 : 34, height: state == .current ? 42 : 34)
                            Image(systemName: state.icon).font(.caption.bold()).foregroundStyle(.white)
                        }
                        .overlay { Circle().stroke(.white, lineWidth: 3) }
                        .shadow(color: state.color.opacity(0.45), radius: 8)
                        Text(checkpoint.name.v(session.language))
                            .font(.system(size: 9, weight: .bold)).foregroundStyle(Theme.primary)
                            .padding(.horizontal, 6).padding(.vertical, 3).background(Theme.surface.opacity(0.94), in: Capsule())
                    }
                }
                .disabled(state == .locked)
                .position(x: size.width * checkpoint.mapPosition.x, y: size.height * checkpoint.mapPosition.y)
                .accessibilityIdentifier("checkpoint_\(checkpoint.id)")
            }
        }.frame(width: size.width, height: size.height)
    }

    private var checkpointCard: some View {
        Group {
            if let checkpoint = session.currentCheckpoint {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("CHECKPOINT \(checkpoint.order + 1)").font(.caption2.bold()).tracking(1).foregroundStyle(Theme.gold)
                        Spacer()
                        Text("\(visitedCount(checkpoint))/\(checkpoint.nuggets.count) SECRETS")
                            .font(.caption2.bold()).foregroundStyle(Theme.teal)
                        Button {
                            withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) {
                                isCheckpointCardPresented = false
                            }
                        } label: {
                            Image(systemName: "xmark")
                                .font(.caption.bold())
                                .foregroundStyle(Theme.mutedInk)
                                .frame(width: 30, height: 30)
                                .background(Theme.surfaceContainer, in: Circle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Close checkpoint details")
                    }
                    Text(checkpoint.name.v(session.language)).font(.title2.bold()).foregroundStyle(Theme.ink)
                    Text(checkpoint.intro.v(session.language)).font(.subheadline).foregroundStyle(Theme.mutedInk).lineLimit(2)
                    HStack(spacing: 10) {
                        Button { selectedTab = .scan } label: { Label("AR Exp", systemImage: "viewfinder") }
                            .buttonStyle(PrimaryButtonStyle())
                        Button(action: onBrowse) {
                            Label("Audio Exp", systemImage: "headphones")
                                .font(.subheadline.bold()).foregroundStyle(Theme.primary)
                                .frame(maxWidth: .infinity).frame(height: 54)
                                .background(Theme.surfaceContainer, in: RoundedRectangle(cornerRadius: 15))
                        }
                        .accessibilityIdentifier("browseCheckpointButton")
                    }
                }
                .padding(18).heritageCard().padding(.horizontal, 16).padding(.bottom, 102)
                .offset(y: isCheckpointCardPresented ? 0 : 420)
                .opacity(isCheckpointCardPresented ? 1 : 0)
                .scaleEffect(isCheckpointCardPresented ? 1 : 0.96, anchor: .bottom)
                .allowsHitTesting(isCheckpointCardPresented)
                .accessibilityHidden(!isCheckpointCardPresented)
            }
        }.frame(maxWidth: 520).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
    }

    private var controls: some View {
        VStack(spacing: 9) {
            Button { zoom(0.4) } label: { Image(systemName: "plus") }
            Button { zoom(-0.4) } label: { Image(systemName: "minus") }
            Button { withAnimation { scale = 1; lastScale = 1; offset = .zero; lastOffset = .zero } } label: { Image(systemName: "location.fill") }
        }
        .font(.headline).foregroundStyle(Theme.primary).padding(11).background(.ultraThinMaterial, in: Capsule()).shadow(radius: 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing).padding(16)
    }

    private var mapGesture: some Gesture {
        MagnifyGesture().onChanged { value in scale = min(max(lastScale * value.magnification, 1), 3.5) }
            .onEnded { _ in lastScale = scale }
            .simultaneously(with: DragGesture().onChanged { value in
                guard scale > 1 else { return }
                offset = CGSize(width: lastOffset.width + value.translation.width, height: lastOffset.height + value.translation.height)
            }.onEnded { _ in lastOffset = offset })
    }

    private func fittedMapSize(in available: CGSize) -> CGSize {
        let ratio: CGFloat = 472 / 774
        let height = available.height
        let width = min(available.width, height * ratio)
        return CGSize(width: width, height: width / ratio)
    }

    private func visitedCount(_ checkpoint: Checkpoint) -> Int { checkpoint.nuggets.filter { visitedNuggetIDs.contains($0.id) }.count }

    private func checkpointState(_ checkpoint: Checkpoint, index: Int) -> CheckpointVisualState {
        if checkpoint.id == session.currentCheckpointID { return .current }
        if visitedCount(checkpoint) == checkpoint.nuggets.count { return .visited }
        if index == 0 { return .available }
        let previous = ordered[index - 1]
        return visitedCount(previous) == previous.nuggets.count ? .available : .locked
    }

    private func select(_ checkpoint: Checkpoint, state: CheckpointVisualState) {
        guard state != .locked else { return }
        withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) {
            session.select(checkpoint: checkpoint)
            isCheckpointCardPresented = true
        }
    }

    private func zoom(_ amount: CGFloat) {
        withAnimation(.snappy) { scale = min(max(scale + amount, 1), 3.5); lastScale = scale }
    }
}

private enum CheckpointVisualState: Equatable {
    case locked, available, current, visited
    var color: Color { switch self { case .locked: .gray; case .available: Theme.gold; case .current: Theme.primary; case .visited: Theme.teal } }
    var icon: String { switch self { case .locked: "lock.fill"; case .available: "circle.fill"; case .current: "location.fill"; case .visited: "checkmark" } }
}
