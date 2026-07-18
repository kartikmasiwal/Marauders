import SwiftUI

struct NuggetRevealCard: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let session: TourSession
    let nugget: Nugget
    let onReplay: () -> Void
    let onClose: () -> Void
    @State private var sweepOffset: CGFloat = -1.2

    var body: some View {
        ZStack {
            Theme.surface.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    hero
                    if nugget.exclusive {
                        Label("GUIDE-EXCLUSIVE SECRET", systemImage: "star.fill")
                            .font(.caption.bold()).tracking(1).foregroundStyle(Theme.gold)
                    }
                    Text(nugget.title.v(session.language))
                        .font(.system(size: 32, weight: .bold, design: .rounded)).foregroundStyle(Theme.ink)
                        .accessibilityIdentifier("nuggetRevealTitle_\(nugget.id)")
                    Text(nugget.text.v(session.language))
                        .font(.body).foregroundStyle(Theme.mutedInk).lineSpacing(5)
                    Button(action: onReplay) { Label("Replay local audio", systemImage: "play.circle.fill") }
                        .buttonStyle(PrimaryButtonStyle())
                }
                .padding(20).padding(.bottom, 110)
            }
            closeButton
        }
    }

    private var hero: some View {
        Image(uiImage: UIImage(contentsOfFile: session.installed.targetURL(for: nugget).path) ?? UIImage())
            .resizable().scaledToFill().frame(height: 310).clipped()
            .overlay {
                if !reduceMotion {
                    LinearGradient(
                        colors: [.clear, Theme.goldLight.opacity(0.72), .white.opacity(0.8), .clear],
                        startPoint: .leading, endPoint: .trailing
                    )
                    .rotationEffect(.degrees(-12)).offset(x: sweepOffset * 420).blendMode(.screen)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay { RoundedRectangle(cornerRadius: 28).stroke(Theme.gold.opacity(0.35), lineWidth: 1) }
            .shadow(color: Theme.gold.opacity(0.2), radius: 20, y: 10)
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeInOut(duration: 1.1).delay(0.15)) { sweepOffset = 1.2 }
            }
    }

    private var closeButton: some View {
        Button(action: onClose) {
            Image(systemName: "xmark").font(.headline).foregroundStyle(Theme.ink)
                .frame(width: 42, height: 42).background(.ultraThinMaterial, in: Circle())
        }
        .buttonStyle(SubtlePressButtonStyle())
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
        .padding(28)
        .accessibilityIdentifier("closeNuggetReveal")
    }
}
