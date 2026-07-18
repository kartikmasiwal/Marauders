import SwiftUI

struct MonumentInfoView: View {
    let monument: Monument
    @ObservedObject var audioPlayer: AudioGuidePlayer
    @State private var selectedAudio: TourPoint?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Image(monument.imageName).resizable().scaledToFill().frame(height: 230).clipped().clipShape(RoundedRectangle(cornerRadius: 24))
                Text(monument.name).font(.system(size: 30, weight: .bold, design: .rounded)).foregroundStyle(Theme.primary)
                Text(monument.summary).font(.body).foregroundStyle(Theme.mutedInk)
                Text("Audio chapters").font(.title2.bold())
                ForEach(monument.points) { point in
                    Button { selectedAudio = point } label: {
                        HStack(spacing: 14) {
                            Text("\(point.number)").font(.headline).foregroundStyle(.white).frame(width: 38, height: 38).background(Theme.primary, in: Circle())
                            VStack(alignment: .leading) { Text(point.title).font(.headline); Text(point.subtitle).font(.caption).foregroundStyle(Theme.mutedInk) }
                            Spacer()
                            Image(systemName: "play.circle.fill").font(.title2).foregroundStyle(Theme.primary)
                        }
                        .foregroundStyle(Theme.ink).padding(14).background(Theme.surface, in: RoundedRectangle(cornerRadius: 18))
                    }
                }
            }.padding(20).padding(.bottom, 100)
        }
        .background(Theme.surfaceLow)
        .sheet(item: $selectedAudio) { AudioPlayerSheet(monument: monument, point: $0, player: audioPlayer) }
    }
}
