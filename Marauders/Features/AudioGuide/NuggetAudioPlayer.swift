import AVFoundation
import Foundation

enum NuggetAudio: Equatable {
    case idle
    case entering(Date)
    case playing(String)
    case exiting(Date)
}

enum AudioTiming {
    static let enterHold: TimeInterval = 0.3
    static let exitHold: TimeInterval = 1.5
    static let fadeIn: TimeInterval = 0.4
    static let fadeOut: TimeInterval = 0.6
    static let crossfade: TimeInterval = 0.5
}

@MainActor
final class NuggetAudioPlayer: NSObject, ObservableObject, AVAudioPlayerDelegate {
    @Published private(set) var state: NuggetAudio = .idle
    @Published private(set) var progress: Double = 0
    @Published private(set) var isPlaying = false

    var onStart: ((String) -> Void)?
    private var player: AVAudioPlayer?
    private var enterTask: Task<Void, Never>?
    private var exitTask: Task<Void, Never>?
    private var progressTimer: Timer?
    private var pendingNuggetID: String?
    private var activeNuggetID: String?

    func targetFound(nugget: Nugget, language: String, directory: URL) {
        exitTask?.cancel()
        if activeNuggetID == nugget.id, player != nil {
            state = .playing(nugget.id)
            return
        }
        if case .playing(let id) = state, id == nugget.id { return }
        if pendingNuggetID == nugget.id { return }

        pendingNuggetID = nugget.id
        let enteredAt = Date()
        state = .entering(enteredAt)
        enterTask?.cancel()
        enterTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(AudioTiming.enterHold))
            guard !Task.isCancelled else { return }
            self?.start(nugget: nugget, language: language, directory: directory)
        }
    }

    func targetLost(nuggetID: String) {
        if pendingNuggetID == nuggetID {
            enterTask?.cancel()
            pendingNuggetID = nil
            if !isPlaying { state = .idle }
        }
        guard case .playing(let playingID) = state, playingID == nuggetID else { return }
        let exitedAt = Date()
        state = .exiting(exitedAt)
        exitTask?.cancel()
        exitTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(AudioTiming.exitHold))
            guard !Task.isCancelled else { return }
            self?.stop(fadeDuration: AudioTiming.fadeOut)
        }
    }

    func replay(nugget: Nugget, language: String, directory: URL) {
        enterTask?.cancel()
        exitTask?.cancel()
        start(nugget: nugget, language: language, directory: directory)
    }

    func toggle() {
        guard let player else { return }
        if player.isPlaying { player.pause(); isPlaying = false } else { player.play(); isPlaying = true }
    }

    func stop(fadeDuration: TimeInterval = 0) {
        player?.stop()
        player = nil
        isPlaying = false
        progress = 0
        state = .idle
        pendingNuggetID = nil
        activeNuggetID = nil
        progressTimer?.invalidate()
    }

    private func start(nugget: Nugget, language: String, directory: URL) {
        guard pendingNuggetID == nil || pendingNuggetID == nugget.id else { return }
        let path = nugget.audio.v(language)
        let url = directory.appendingPathComponent(path)
        do {
            let next = try AVAudioPlayer(contentsOf: url)
            player?.stop()
            player = next
            next.delegate = self
            next.prepareToPlay()
            next.play()
            state = .playing(nugget.id)
            pendingNuggetID = nil
            activeNuggetID = nugget.id
            isPlaying = true
            onStart?(nugget.id)
            startProgressTimer()
        } catch {
            state = .idle
            pendingNuggetID = nil
            isPlaying = false
        }
    }

    private func startProgressTimer() {
        progressTimer?.invalidate()
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, let player = self.player, player.duration > 0 else { return }
                self.progress = player.currentTime / player.duration
            }
        }
    }

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in self.stop() }
    }
}
