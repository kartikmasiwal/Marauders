import AVFoundation
import SwiftUI

struct TajCheckpointDetailView: View {
    let chapterID: String
    let language: String
    @ObservedObject var progressStore: TajTourProgressStore
    @ObservedObject var insights: TajAIInsightStore
    @ObservedObject var narrator: AudioNarrationController
    @ObservedObject var audioPlayer: NuggetAudioPlayer
    @ObservedObject var ambientPlayer: AmbientAudioPlayer
    let onOpenAR: () -> Void
    let onOpenBrowse: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showARUnavailable = false
    @State private var showGuideChat = false

    private var chapter: TajMapCheckpoint? {
        progressStore.chapters.first { $0.id == chapterID }
    }

    var body: some View {
        let loaded = AnyView(navigationContent.task(id: chapterID) {
            if let chapter { await insights.load(for: chapter) }
        })
        let observed = AnyView(loaded.onChange(of: narrator.state) { oldState, newState in
            narrationStateChanged(oldState, newState)
        })
        let cleaned = AnyView(observed.onDisappear(perform: stopNarration))
        return AnyView(cleaned.alert("AR preview unavailable", isPresented: $showARUnavailable) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("This chapter has no verified AR target yet. Its curated text and Audio Experience remain available offline.")
        })
    }

    private var navigationContent: some View {
        NavigationStack {
            ScrollView {
                chapterContent
            }
            .background(Theme.surfaceLow)
            .navigationTitle("Chapter \(chapter?.chapterNumber ?? 0)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    @ViewBuilder
    private var chapterContent: some View {
        if let chapter {
            VStack(alignment: .leading, spacing: 20) {
                chapterHeader(chapter)
                informationCard(title: "Verified tour content", icon: "checkmark.seal.fill", text: chapter.verifiedInformation)
                aiInformation(chapter)
                detailGrid(chapter)
                audioExperience(chapter)
                actionButtons(chapter)
            }
            .padding(20)
            .padding(.bottom, 24)
        }
    }

    private func narrationStateChanged(_: AudioNarrationController.State, _ state: AudioNarrationController.State) {
        ambientPlayer.setDucked(state == .speaking || state == .pausing, for: .checkpointSpeech)
    }

    private func stopNarration() {
        narrator.stop()
        ambientPlayer.setDucked(false, for: .checkpointSpeech)
    }

    private func chapterHeader(_ chapter: TajMapCheckpoint) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("CHAPTER \(chapter.chapterNumber) OF 6", systemImage: chapter.status.icon)
                    .font(.caption.bold()).tracking(1)
                    .foregroundStyle(chapter.status.color)
                Spacer()
                Text(chapter.status.label.uppercased())
                    .font(.caption2.bold()).tracking(0.8)
                    .foregroundStyle(chapter.status.color)
                    .padding(.horizontal, 9).padding(.vertical, 6)
                    .background(chapter.status.color.opacity(0.12), in: Capsule())
            }
            Text(chapter.name)
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.ink)
            Text("A location-specific chapter in your Taj Mahal route.")
                .foregroundStyle(Theme.mutedInk)
        }
        .padding(18)
        .heritageCard()
    }

    private func informationCard(title: String, icon: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: icon).font(.headline).foregroundStyle(Theme.primary)
            Text(text).foregroundStyle(Theme.mutedInk).lineSpacing(4)
        }
        .padding(18)
        .heritageCard()
    }

    @ViewBuilder
    private func aiInformation(_ chapter: TajMapCheckpoint) -> some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack {
                Label("Offline guide note", systemImage: "book.closed.fill").font(.headline).foregroundStyle(Theme.primary)
                Spacer()
                Text("AVAILABLE OFFLINE")
                    .font(.system(size: 9, weight: .bold)).tracking(0.7).foregroundStyle(Theme.teal)
            }
            switch insights.state(for: chapter.id) {
            case .idle, .loading:
                HStack { ProgressView(); Text("Preparing offline guide note…") }.foregroundStyle(Theme.mutedInk)
            case .success(let text):
                Text(text).foregroundStyle(Theme.mutedInk).lineSpacing(4)
                Text("This curated local fallback is separate from live AI questions, which are available in mapped AR chapters.")
                    .font(.caption).foregroundStyle(Theme.mutedInk.opacity(0.8))
            case .failure(let message):
                Label(message, systemImage: "exclamationmark.triangle.fill").foregroundStyle(Theme.primary)
                Button("Retry") { Task { await insights.retry(for: chapter) } }
                    .buttonStyle(.bordered)
            }
            Button {
                showGuideChat = true
            } label: {
                Label("Ask the guide a question", systemImage: "bubble.left.and.text.bubble.right")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(Theme.primary)
            .accessibilityIdentifier("askGuideButton")
        }
        .padding(18)
        .heritageCard()
        .sheet(isPresented: $showGuideChat) {
            GuideChatView(
                monumentID: "taj_mahal",
                checkpointID: TajAIInsightStore.backendCheckpointID(forChapter: chapter.id),
                language: language
            )
        }
    }

    private func detailGrid(_ chapter: TajMapCheckpoint) -> some View {
        VStack(spacing: 12) {
            detailRow("Architecture", "building.columns.fill", chapter.architecture)
            detailRow("Historical context", "clock.fill", chapter.historicalContext)
            detailRow("Interesting fact", "lightbulb.fill", chapter.interestingFact)
            detailRow("Visitor guidance", "figure.walk", chapter.visitorGuidance)
        }
    }

    private func detailRow(_ title: String, _ icon: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 13) {
            Image(systemName: icon).foregroundStyle(Theme.gold).frame(width: 24)
            VStack(alignment: .leading, spacing: 5) {
                Text(title).font(.subheadline.bold()).foregroundStyle(Theme.ink)
                Text(text).font(.subheadline).foregroundStyle(Theme.mutedInk)
            }
            Spacer(minLength: 0)
        }
        .padding(15)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 16))
    }

    private func audioExperience(_ chapter: TajMapCheckpoint) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Audio Experience", systemImage: "waveform.circle.fill")
                .font(.headline).foregroundStyle(Theme.primary)
            ProgressView(value: narrator.progress).tint(Theme.gold)
            HStack {
                Text(time(narrator.elapsed))
                Spacer()
                Text("Approx. \(time(narrator.estimatedDuration))")
            }
            .font(.caption.monospacedDigit()).foregroundStyle(Theme.mutedInk)
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) { narrationButtons(chapter) }
                VStack(spacing: 10) { narrationButtons(chapter) }
            }
            .buttonStyle(.bordered)
            HStack {
                Image(systemName: "tortoise.fill")
                Slider(
                    value: Binding(
                        get: { Double(narrator.speechRate) },
                        set: { narrator.speechRate = Float($0) }
                    ),
                    in: Double(AVSpeechUtteranceMinimumSpeechRate)...Double(AVSpeechUtteranceMaximumSpeechRate)
                )
                .disabled(narrator.state != .idle)
                Image(systemName: "hare.fill")
            }
            .foregroundStyle(Theme.mutedInk)
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Narration speed")
        }
        .padding(18)
        .heritageCard()
    }

    @ViewBuilder
    private func narrationButtons(_ chapter: TajMapCheckpoint) -> some View {
        Button { play(chapter) } label: { Label("Play", systemImage: "play.fill").frame(minHeight: 44) }
        Button { narrator.state == .paused ? narrator.resume() : narrator.pause() } label: {
            Label(narrator.state == .paused ? "Resume" : "Pause", systemImage: narrator.state == .paused ? "play.fill" : "pause.fill")
                .frame(minHeight: 44)
        }
        .disabled(narrator.state == .idle || narrator.state == .pausing)
        Button { narrator.stop() } label: { Label("Stop", systemImage: "stop.fill").frame(minHeight: 44) }
            .disabled(narrator.state == .idle)
        Button { narrator.restart() } label: { Image(systemName: "backward.end.fill").frame(minWidth: 44, minHeight: 44) }
            .disabled(narrator.state == .idle)
            .accessibilityLabel("Restart narration")
    }

    private func actionButtons(_ chapter: TajMapCheckpoint) -> some View {
        VStack(spacing: 12) {
            Button {
                narrator.stop()
                onOpenBrowse()
            } label: {
                Label("Browse Local Stories", systemImage: "headphones").frame(minHeight: 44)
            }
            .buttonStyle(.bordered)
            .accessibilityIdentifier("tajBrowseStoriesButton")

            Button {
                narrator.stop()
                if chapter.arAssetName == nil { showARUnavailable = true } else { onOpenAR() }
            } label: {
                Label("AR Experience", systemImage: "arkit").frame(minHeight: 44)
            }
            .buttonStyle(PrimaryButtonStyle())

            Button {
                let completion = { _ = progressStore.completeSelectedChapter() }
                if reduceMotion { completion() } else { withAnimation(.easeInOut(duration: 0.3), completion) }
            } label: {
                Label(
                    chapter.status == .completed ? "Chapter Completed" : "Complete Chapter",
                    systemImage: chapter.status == .completed ? "checkmark.seal.fill" : "checkmark.circle"
                ).frame(minHeight: 44)
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.teal)
            .disabled(!progressStore.canCompleteSelectedChapter)
            .accessibilityIdentifier("tajCompleteChapterButton")
        }
    }

    private func play(_ chapter: TajMapCheckpoint) {
        audioPlayer.stop()
        let insight: String
        if case .success(let value) = insights.state(for: chapter.id) { insight = value } else { insight = chapter.fallbackAIInformation }
        let text = [chapter.verifiedInformation, insight, chapter.architecture, chapter.historicalContext, chapter.interestingFact, chapter.visitorGuidance]
            .filter { !$0.isEmpty }.joined(separator: " ")
        narrator.play(text: text, languageCode: "en", chapterID: chapter.id)
    }

    private func time(_ interval: TimeInterval) -> String {
        guard interval.isFinite else { return "0:00" }
        let seconds = max(Int(interval), 0)
        return "\(seconds / 60):\(String(format: "%02d", seconds % 60))"
    }
}

extension CheckpointStatus {
    var color: Color {
        switch self {
        case .completed: Theme.teal
        case .active: Theme.primary
        case .available: Theme.gold
        case .upcoming: Theme.gold.opacity(0.65)
        case .locked: Theme.mutedInk
        }
    }

    var icon: String {
        switch self {
        case .completed: "checkmark"
        case .active: "location.fill"
        case .available: "circle.fill"
        case .upcoming: "clock.fill"
        case .locked: "lock.fill"
        }
    }

    var label: String {
        switch self {
        case .completed: "Completed"
        case .active: "Current"
        case .available: "Available"
        case .upcoming: "Upcoming"
        case .locked: "Locked"
        }
    }
}
