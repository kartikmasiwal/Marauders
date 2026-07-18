import SwiftUI

struct MonumentInfoView: View {
    @ObservedObject var session: TourSession
    @ObservedObject var audioPlayer: NuggetAudioPlayer
    let visitedCount: Int

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
            Label("\(visitedCount) of \(session.installed.package.checkpoints.flatMap(\.nuggets).count) secrets found", systemImage: "sparkles")
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
            ForEach(session.installed.package.checkpoints.sorted { $0.order < $1.order }) { checkpoint in
                Button { session.select(checkpoint: checkpoint) } label: {
                    HStack {
                        Text("\(checkpoint.order + 1)").font(.headline).foregroundStyle(.white).frame(width: 36, height: 36).background(Theme.primary, in: Circle())
                        VStack(alignment: .leading) {
                            Text(checkpoint.name.v(session.language)).font(.headline)
                            Text("\(checkpoint.nuggets.count) stories").font(.caption).foregroundStyle(Theme.mutedInk)
                        }
                        Spacer()
                    }.foregroundStyle(Theme.ink).padding(12).background(Theme.surface, in: RoundedRectangle(cornerRadius: 16))
                }
            }
        }
    }
}
