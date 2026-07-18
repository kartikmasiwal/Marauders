import SwiftUI

struct BrowseModeView: View {
    @ObservedObject var session: TourSession
    let onEngage: (Checkpoint, Nugget) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var revealedNugget: Nugget?

    var body: some View {
        ZStack {
            Theme.surfaceLow.ignoresSafeArea()
            if let nugget = revealedNugget {
                NuggetRevealCard(
                    session: session,
                    nugget: nugget,
                    onReplay: { replay(nugget) },
                    onClose: { withAnimation(.snappy) { revealedNugget = nil } }
                )
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
            } else {
                list
            }
        }
    }

    private var list: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    checkpointPicker
                    if let checkpoint = session.currentCheckpoint {
                        Text(checkpoint.intro.v(session.language)).foregroundStyle(Theme.mutedInk)
                        ForEach(checkpoint.nuggets) { nugget in nuggetCard(checkpoint: checkpoint, nugget: nugget) }
                    }
                }.padding(20)
            }
            .background(Theme.surfaceLow)
            .navigationTitle("Audio Experience")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }

    private var checkpointPicker: some View {
        Picker("Checkpoint", selection: $session.currentCheckpointID) {
            ForEach(session.installed.package.checkpoints.sorted { $0.order < $1.order }) { checkpoint in
                Text("\(checkpoint.order + 1). \(checkpoint.name.v(session.language))").tag(checkpoint.id)
            }
        }
        .pickerStyle(.menu)
        .tint(Theme.primary)
    }

    private func nuggetCard(checkpoint: Checkpoint, nugget: Nugget) -> some View {
        Button {
            onEngage(checkpoint, nugget)
            withAnimation(.snappy) { revealedNugget = nugget }
        } label: {
            HStack(spacing: 14) {
                Image(uiImage: UIImage(contentsOfFile: session.installed.targetURL(for: nugget).path) ?? UIImage())
                    .resizable().scaledToFill().frame(width: 88, height: 88).clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 16)).allowsHitTesting(false)
                VStack(alignment: .leading, spacing: 7) {
                    if nugget.exclusive { Text("★ EXCLUSIVE").font(.caption2.bold()).tracking(0.8).foregroundStyle(Theme.gold) }
                    Text(nugget.title.v(session.language)).font(.headline).foregroundStyle(Theme.ink)
                    Text(nugget.text.v(session.language)).font(.caption).foregroundStyle(Theme.mutedInk).lineLimit(2)
                }
                Spacer()
                Image(systemName: "play.circle.fill").font(.title2).foregroundStyle(Theme.primary)
            }
            .padding(12).background(Theme.surface, in: RoundedRectangle(cornerRadius: 20))
            .overlay { RoundedRectangle(cornerRadius: 20).stroke(Theme.outline.opacity(0.55)) }
        }
        .accessibilityIdentifier("browseNugget_\(nugget.id)")
    }

    private func replay(_ nugget: Nugget) {
        guard let checkpoint = session.checkpoint(containing: nugget.id) else { return }
        onEngage(checkpoint, nugget)
    }
}
