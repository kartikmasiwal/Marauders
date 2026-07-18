import SwiftUI

struct InteractiveMapView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ObservedObject var session: TourSession
    let visitedNuggetIDs: Set<String>
    @Binding var selectedTab: TourContainerView.TourTab
    let onBrowse: () -> Void
    let onSelectCheckpoint: (Checkpoint) -> Void
    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var isCheckpointCardPresented = true
    @State private var completionBurst = false

    private var ordered: [Checkpoint] { session.installed.package.checkpoints.sorted { $0.order < $1.order } }
    private var isZomatoJourney: Bool { session.installed.package.monument.id == "zomato_farmhouse" }
    private var allCheckpointsCompleted: Bool { !ordered.isEmpty && ordered.allSatisfy(isCompleted) }

    var body: some View {
        GeometryReader { proxy in
            let mapSize = fittedMapSize(in: proxy.size)
            ZStack {
                Theme.surfaceContainer.ignoresSafeArea()
                ZStack {
                    Image(mapImageName)
                        .resizable().scaledToFit().frame(width: mapSize.width, height: mapSize.height)
                    trail(in: mapSize)
                    checkpoints(in: mapSize, viewport: proxy.size)
                    completionShimmer(in: mapSize)
                }
                .frame(width: mapSize.width, height: mapSize.height)
                .scaleEffect(scale).offset(offset)
                .gesture(mapGesture(viewport: proxy.size, mapSize: mapSize))
                .simultaneousGesture(
                    TapGesture(count: 2).onEnded { resetMap() }
                )
                controls(viewport: proxy.size, mapSize: mapSize)
                checkpointCard
            }
            .clipped()
            .onChange(of: proxy.size) { _, newSize in
                offset = clamped(offset, scale: scale, viewport: newSize, mapSize: fittedMapSize(in: newSize))
                lastOffset = offset
            }
            .onChange(of: session.currentCheckpointID) { _, id in
                guard let checkpoint = ordered.first(where: { $0.id == id }) else { return }
                focus(checkpoint, viewport: proxy.size, mapSize: mapSize)
            }
            .onChange(of: allCheckpointsCompleted) { wasComplete, isComplete in
                guard isZomatoJourney, !wasComplete, isComplete else { return }
                completionBurst = true
                Task {
                    try? await Task.sleep(for: .seconds(1.8))
                    withAnimation(.easeOut(duration: 0.6)) { completionBurst = false }
                }
            }
        }
    }

    private var mapImageName: String {
        switch session.installed.package.monument.id {
        case "national_war_memorial": "WarMemorialMap"
        case "zomato_farmhouse": "ZomatoFarmMap"
        default: "TajMahalMap"
        }
    }

    @ViewBuilder
    private func trail(in size: CGSize) -> some View {
        if isZomatoJourney {
            dynamicTrail(in: size)
        } else {
            staticTrail(in: size)
        }
    }

    private func staticTrail(in size: CGSize) -> some View {
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

    private func dynamicTrail(in size: CGSize) -> some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { timeline in
            let elapsed = timeline.date.timeIntervalSinceReferenceDate
            let travel = elapsed.truncatingRemainder(dividingBy: 2.4) / 2.4
            let breathe = 0.78 + 0.16 * (0.5 + 0.5 * sin(elapsed * 1.8))

            Canvas { context, _ in
                guard ordered.count > 1 else { return }
                for index in 0..<(ordered.count - 1) {
                    let source = ordered[index]
                    let destination = ordered[index + 1]
                    let start = point(for: source, in: size)
                    let end = point(for: destination, in: size)
                    var segment = Path()
                    segment.move(to: start)
                    segment.addLine(to: end)

                    let sourceComplete = isCompleted(source)
                    let destinationReached = isCompleted(destination) || destination.id == session.currentCheckpointID
                    let completed = sourceComplete && destinationReached
                    let active = sourceComplete && !destinationReached

                    if completed || allCheckpointsCompleted {
                        context.drawLayer { layer in
                            layer.addFilter(.shadow(color: Theme.gold.opacity(0.55), radius: 5))
                            layer.stroke(segment, with: .color(Theme.gold.opacity(breathe)), style: StrokeStyle(lineWidth: 4, lineCap: .round, dash: [6, 8]))
                        }
                        drawParticle(context: context, from: start, to: end, progress: travel, opacity: 0.62)
                    } else if active {
                        context.drawLayer { layer in
                            layer.addFilter(.shadow(color: Theme.goldLight.opacity(0.8), radius: 7))
                            layer.stroke(segment, with: .color(Theme.goldLight), style: StrokeStyle(lineWidth: 4, lineCap: .round, dash: [6, 8], dashPhase: -CGFloat(elapsed * 18)))
                        }
                        drawParticle(context: context, from: start, to: end, progress: travel, opacity: 1)
                        drawParticle(context: context, from: start, to: end, progress: (travel + 0.34).truncatingRemainder(dividingBy: 1), opacity: 0.55)
                    } else {
                        context.stroke(segment, with: .color(Theme.mutedInk.opacity(0.18)), style: StrokeStyle(lineWidth: 3, lineCap: .round, dash: [5, 9]))
                    }
                }
            }
        }
        .frame(width: size.width, height: size.height)
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private func checkpoints(in size: CGSize, viewport: CGSize) -> some View {
        if isZomatoJourney {
            TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { timeline in
                let pulse = timeline.date.timeIntervalSinceReferenceDate
                checkpointLayer(in: size, viewport: viewport, pulse: pulse)
            }
        } else {
            checkpointLayer(in: size, viewport: viewport, pulse: nil)
        }
    }

    private func checkpointLayer(in size: CGSize, viewport: CGSize, pulse: TimeInterval?) -> some View {
        ZStack {
            ForEach(Array(ordered.enumerated()), id: \.element.id) { index, checkpoint in
                let state = checkpointState(checkpoint, index: index)
                let wave = pulse.map { CGFloat(sin($0 * 2.2)) } ?? 0
                let markerScale: CGFloat = state == .current ? 1.025 + wave * 0.025 : (state == .visited ? 1.008 + wave * 0.008 : 1)
                Button { select(checkpoint, state: state, viewport: viewport, mapSize: size) } label: {
                    VStack(spacing: 4) {
                        ZStack {
                            if state == .current, isZomatoJourney {
                                Circle()
                                    .stroke(Theme.goldLight.opacity(0.3 - Double(wave) * 0.08), lineWidth: 2)
                                    .frame(width: 52, height: 52)
                                    .scaleEffect(1.08 + wave * 0.08)
                            }
                            Circle().fill(state.color).frame(width: state == .current ? 42 : 34, height: state == .current ? 42 : 34)
                            Image(systemName: state.icon).font(.caption.bold()).foregroundStyle(.white)
                        }
                        .scaleEffect(markerScale)
                        .overlay { Circle().stroke(.white, lineWidth: 3) }
                        .shadow(color: state.color.opacity(state == .current && isZomatoJourney ? 0.68 : 0.45), radius: state == .current && isZomatoJourney ? 12 : 8)
                        Text(checkpoint.name.v(session.language))
                            .font(.system(size: 9, weight: .bold)).foregroundStyle(Theme.primary)
                            .padding(.horizontal, 6).padding(.vertical, 3).background(Theme.surface.opacity(0.94), in: Capsule())
                    }
                }
                .disabled(state == .locked)
                .simultaneousGesture(
                    LongPressGesture(minimumDuration: 0.45).onEnded { _ in
                        select(checkpoint, state: state, viewport: viewport, mapSize: size)
                    }
                )
                .position(x: size.width * checkpoint.mapPosition.x, y: size.height * checkpoint.mapPosition.y)
                .accessibilityIdentifier("checkpoint_\(checkpoint.id)")
            }
        }.frame(width: size.width, height: size.height)
    }

    @ViewBuilder
    private func completionShimmer(in size: CGSize) -> some View {
        if isZomatoJourney, completionBurst {
            TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { timeline in
                let progress = timeline.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 1.5) / 1.5
                LinearGradient(
                    colors: [.clear, Theme.goldLight.opacity(0.15), .white.opacity(0.34), .clear],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .rotationEffect(.degrees(-12))
                .offset(x: (CGFloat(progress) * 2 - 1) * size.width)
                .blendMode(.screen)
            }
            .frame(width: size.width, height: size.height)
            .allowsHitTesting(false)
            .transition(.opacity)
        }
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
                    Text(checkpoint.intro.v(session.language)).font(.subheadline).foregroundStyle(Theme.mutedInk)
                        .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
                    checkpointActions
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

    private func controls(viewport: CGSize, mapSize: CGSize) -> some View {
        VStack(spacing: 9) {
            Button { zoom(0.4, viewport: viewport, mapSize: mapSize) } label: { Image(systemName: "plus").frame(width: 36, height: 36) }
            Button { zoom(-0.4, viewport: viewport, mapSize: mapSize) } label: { Image(systemName: "minus").frame(width: 36, height: 36) }
            Button { resetMap() } label: { Image(systemName: "location.fill").frame(width: 36, height: 36) }
        }
        .font(.headline).foregroundStyle(Theme.primary).padding(11).background(.ultraThinMaterial, in: Capsule()).shadow(radius: 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing).padding(16)
    }

    private var checkpointActions: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 10) { scanButton; browseButton }
            VStack(spacing: 10) { scanButton; browseButton }
        }
    }

    private var scanButton: some View {
        Button { selectedTab = .scan } label: { Label("Scan", systemImage: "viewfinder") }
            .buttonStyle(PrimaryButtonStyle())
    }

    private var browseButton: some View {
        Button(action: onBrowse) {
            Label("Browse", systemImage: "rectangle.grid.1x2")
                .font(.subheadline.bold()).foregroundStyle(Theme.primary)
                .frame(maxWidth: .infinity).frame(height: 54)
                .background(Theme.surfaceContainer, in: RoundedRectangle(cornerRadius: 15))
        }
        .accessibilityIdentifier("browseCheckpointButton")
    }

    private func mapGesture(viewport: CGSize, mapSize: CGSize) -> some Gesture {
        MagnifyGesture().onChanged { value in
            scale = min(max(lastScale * value.magnification, 1), 3.5)
            offset = clamped(offset, scale: scale, viewport: viewport, mapSize: mapSize)
        }
            .onEnded { _ in
                lastScale = scale
                offset = clamped(offset, scale: scale, viewport: viewport, mapSize: mapSize)
                lastOffset = offset
            }
            .simultaneously(with: DragGesture().onChanged { value in
                guard scale > 1 else { return }
                let proposed = CGSize(width: lastOffset.width + value.translation.width, height: lastOffset.height + value.translation.height)
                offset = clamped(proposed, scale: scale, viewport: viewport, mapSize: mapSize)
            }.onEnded { _ in lastOffset = offset })
    }

    private func fittedMapSize(in available: CGSize) -> CGSize {
        let ratio = mapAspectRatio
        let widthAtFullHeight = available.height * ratio
        if widthAtFullHeight <= available.width {
            return CGSize(width: widthAtFullHeight, height: available.height)
        }
        return CGSize(width: available.width, height: available.width / ratio)
    }

    private func point(for checkpoint: Checkpoint, in size: CGSize) -> CGPoint {
        CGPoint(x: size.width * checkpoint.mapPosition.x, y: size.height * checkpoint.mapPosition.y)
    }

    private func isCompleted(_ checkpoint: Checkpoint) -> Bool {
        !checkpoint.nuggets.isEmpty && checkpoint.nuggets.allSatisfy { visitedNuggetIDs.contains($0.id) }
    }

    private func drawParticle(context: GraphicsContext, from start: CGPoint, to end: CGPoint, progress: Double, opacity: Double) {
        let amount = CGFloat(progress)
        let x = start.x + (end.x - start.x) * amount
        let y = start.y + (end.y - start.y) * amount
        let rect = CGRect(x: x - 3, y: y - 3, width: 6, height: 6)
        context.fill(Path(ellipseIn: rect), with: .color(Theme.goldLight.opacity(opacity)))
    }

    private func visitedCount(_ checkpoint: Checkpoint) -> Int { checkpoint.nuggets.filter { visitedNuggetIDs.contains($0.id) }.count }

    private func checkpointState(_ checkpoint: Checkpoint, index: Int) -> CheckpointVisualState {
        if checkpoint.id == session.currentCheckpointID { return .current }
        if visitedCount(checkpoint) == checkpoint.nuggets.count { return .visited }
        if index == 0 { return .available }
        let previous = ordered[index - 1]
        return visitedCount(previous) == previous.nuggets.count ? .available : .locked
    }

    private func select(_ checkpoint: Checkpoint, state: CheckpointVisualState, viewport: CGSize, mapSize: CGSize) {
        guard state != .locked else { return }
        withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) {
            onSelectCheckpoint(checkpoint)
            isCheckpointCardPresented = true
            focus(checkpoint, viewport: viewport, mapSize: mapSize)
        }
    }

    private func zoom(_ amount: CGFloat, viewport: CGSize, mapSize: CGSize) {
        withAnimation(.snappy) {
            scale = min(max(scale + amount, 1), 3.5)
            offset = clamped(offset, scale: scale, viewport: viewport, mapSize: mapSize)
            if scale == 1 { offset = .zero }
            lastScale = scale
            lastOffset = offset
        }
    }

    private func resetMap() {
        withAnimation(.snappy) {
            scale = 1
            lastScale = 1
            offset = .zero
            lastOffset = .zero
        }
    }

    private func focus(_ checkpoint: Checkpoint, viewport: CGSize, mapSize: CGSize) {
        guard scale > 1 else { return }
        let point = CGPoint(x: mapSize.width * checkpoint.mapPosition.x, y: mapSize.height * checkpoint.mapPosition.y)
        let centered = CGSize(
            width: -(point.x - mapSize.width / 2) * scale,
            height: -(point.y - mapSize.height / 2) * scale
        )
        offset = clamped(centered, scale: scale, viewport: viewport, mapSize: mapSize)
        lastOffset = offset
    }

    private func clamped(_ proposed: CGSize, scale: CGFloat, viewport: CGSize, mapSize: CGSize) -> CGSize {
        guard scale > 1 else { return .zero }
        let maxX = max((mapSize.width * scale - viewport.width) / 2, 0)
        let maxY = max((mapSize.height * scale - viewport.height) / 2, 0)
        return CGSize(
            width: min(max(proposed.width, -maxX), maxX),
            height: min(max(proposed.height, -maxY), maxY)
        )
    }

    private var mapAspectRatio: CGFloat {
        switch session.installed.package.monument.id {
        case "national_war_memorial": 470 / 780
        case "zomato_farmhouse": 474 / 784
        default: 472 / 774
        }
    }
}

private enum CheckpointVisualState: Equatable {
    case locked, available, current, visited
    var color: Color { switch self { case .locked: .gray; case .available: Theme.gold; case .current: Theme.primary; case .visited: Theme.teal } }
    var icon: String { switch self { case .locked: "lock.fill"; case .available: "circle.fill"; case .current: "location.fill"; case .visited: "checkmark" } }
}
