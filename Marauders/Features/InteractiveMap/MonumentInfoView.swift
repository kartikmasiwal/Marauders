import SwiftUI

struct MonumentInfoView: View {
    @ObservedObject var session: TourSession
    @ObservedObject var audioPlayer: NuggetAudioPlayer
    let visitedNuggetIDs: Set<String>

    private var orderedCheckpoints: [Checkpoint] {
        session.installed.package.checkpoints.sorted { $0.order < $1.order }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                if let nugget = session.activeNugget { activeNugget(nugget) } else { emptyState }
                checkpointList
            }.padding(20).padding(.bottom, 105)
        }.background(Theme.surfaceLow)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(session.installed.package.monument.name.v(session.language)).font(.system(size: 30, weight: .bold, design: .rounded)).foregroundStyle(Theme.primary)
            Text(session.installed.package.monument.overview.v(session.language)).foregroundStyle(Theme.mutedInk)
            Label("\(visitedNuggetIDs.count) of \(session.installed.package.checkpoints.flatMap(\.nuggets).count) secrets found", systemImage: "sparkles")
                .font(.subheadline.bold()).foregroundStyle(Theme.teal)
        }
    }

    private func activeNugget(_ nugget: Nugget) -> some View {
        VStack(alignment: .leading, spacing: 13) {
            if nugget.exclusive { Text("★ GUIDE-EXCLUSIVE SECRET").font(.caption.bold()).tracking(1).foregroundStyle(Theme.gold) }
            Text(nugget.title.v(session.language)).font(.title2.bold())
            Text(nugget.text.v(session.language)).foregroundStyle(Theme.mutedInk)
            Button {
                audioPlayer.replay(nugget: nugget, language: session.language, directory: session.installed.directory)
            } label: { Label("Replay local audio", systemImage: "play.circle.fill") }
            .buttonStyle(PrimaryButtonStyle())
        }.padding(18).heritageCard()
    }

    private var emptyState: some View {
        ContentUnavailableView("No active story", systemImage: "viewfinder", description: Text("Scan a target to reveal its nugget here."))
            .frame(maxWidth: .infinity).padding(.vertical, 24)
    }

    private var checkpointList: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Tour checkpoints").font(.title3.bold())
            ForEach(Array(orderedCheckpoints.enumerated()), id: \.element.id) { index, checkpoint in
                Button { session.select(checkpoint: checkpoint) } label: {
                    HStack(spacing: 12) {
                        Text("\(checkpoint.order + 1)").font(.headline).foregroundStyle(.white).frame(width: 36, height: 36).background(Theme.primary, in: Circle())
                        VStack(alignment: .leading, spacing: 4) {
                            Text(checkpoint.name.v(session.language)).font(.headline)
                            Text(checkpoint.intro.v(session.language)).font(.caption).foregroundStyle(Theme.mutedInk).lineLimit(1)
                        }
                        Spacer()
                        if let status = status(for: checkpoint, index: index) {
                            Text(status.title.uppercased())
                                .font(.system(size: 9, weight: .bold)).tracking(0.6)
                                .foregroundStyle(status.color)
                                .padding(.horizontal, 8).padding(.vertical, 5)
                                .background(status.color.opacity(0.1), in: Capsule())
                        }
                    }.foregroundStyle(Theme.ink).padding(12).background(Theme.surface, in: RoundedRectangle(cornerRadius: 16))
                }
            }
        }
    }

    private func status(for checkpoint: Checkpoint, index: Int) -> CheckpointInfoStatus? {
        if checkpoint.nuggets.allSatisfy({ visitedNuggetIDs.contains($0.id) }) { return .completed }
        if checkpoint.id == session.currentCheckpointID { return .current }
        guard index > 0 else { return nil }
        let previous = orderedCheckpoints[index - 1]
        return previous.nuggets.allSatisfy({ visitedNuggetIDs.contains($0.id) }) ? nil : .locked
    }
}

private enum CheckpointInfoStatus {
    case locked, current, completed

    var title: String {
        switch self { case .locked: "Locked"; case .current: "Current"; case .completed: "Completed" }
    }

    var color: Color {
        switch self { case .locked: Theme.mutedInk; case .current: Theme.primary; case .completed: Theme.teal }
    }
}
