import SwiftUI

struct AudioPlayerSheet: View {
    let monument: Monument
    let point: TourPoint
    @ObservedObject var player: AudioGuidePlayer
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 22) {
            Capsule().fill(Theme.mutedInk.opacity(0.2)).frame(width: 42, height: 5)
            Image(monument.imageName)
                .resizable().scaledToFill().frame(height: 190).clipped()
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            VStack(spacing: 6) {
                Text("CHAPTER \(point.number) OF \(monument.points.count)").font(.caption.bold()).tracking(1.4).foregroundStyle(Theme.gold)
                Text(point.title).font(.system(size: 28, weight: .bold, design: .rounded)).multilineTextAlignment(.center)
                Text(point.subtitle).foregroundStyle(Theme.mutedInk)
            }
            VStack(spacing: 8) {
                Slider(value: Binding(get: { player.progress }, set: player.seek), in: 0...1).tint(Theme.gold)
                HStack {
                    Text(time(point.duration * player.progress))
                    Spacer()
                    Text("-\(time(point.duration * (1 - player.progress)))")
                }.font(.caption.monospacedDigit()).foregroundStyle(Theme.mutedInk)
            }
            HStack(spacing: 35) {
                Button { select(offset: -1) } label: { Image(systemName: "backward.end.fill") }
                Button(action: player.toggle) {
                    Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                        .font(.title).foregroundStyle(.white).frame(width: 70, height: 70).background(Theme.primary, in: Circle())
                }
                Button { select(offset: 1) } label: { Image(systemName: "forward.end.fill") }
            }
            .font(.title2).foregroundStyle(Theme.primary)
            Text(point.details).font(.subheadline).foregroundStyle(Theme.mutedInk).multilineTextAlignment(.center).lineLimit(3)
            Spacer(minLength: 0)
        }
        .padding(22)
        .background(Theme.surface)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.hidden)
        .onAppear { if player.point?.id != point.id { player.play(point) } }
    }

    private func select(offset: Int) {
        guard let current = player.point, let index = monument.points.firstIndex(of: current) else { return }
        let next = min(max(index + offset, 0), monument.points.count - 1)
        player.play(monument.points[next])
    }

    private func time(_ duration: TimeInterval) -> String {
        String(format: "%d:%02d", Int(duration) / 60, Int(duration) % 60)
    }
}
