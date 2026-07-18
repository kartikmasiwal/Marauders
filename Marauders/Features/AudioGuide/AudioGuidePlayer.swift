import AVFoundation
import Foundation

@MainActor
final class AudioGuidePlayer: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {
    @Published private(set) var point: TourPoint?
    @Published private(set) var isPlaying = false
    @Published private(set) var progress: Double = 0

    private let synthesizer = AVSpeechSynthesizer()
    private var timer: Timer?
    private var elapsed: TimeInterval = 0

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    func play(_ point: TourPoint) {
        if self.point?.id == point.id, synthesizer.isPaused {
            synthesizer.continueSpeaking()
            isPlaying = true
            startTimer()
            return
        }

        synthesizer.stopSpeaking(at: .immediate)
        self.point = point
        elapsed = 0
        progress = 0
        let utterance = AVSpeechUtterance(string: "Chapter \(point.number). \(point.title). \(point.subtitle). \(point.details)")
        utterance.voice = AVSpeechSynthesisVoice(language: "en-IN") ?? AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = 0.46
        utterance.pitchMultiplier = 0.94
        synthesizer.speak(utterance)
        isPlaying = true
        startTimer()
    }

    func toggle() {
        guard let point else { return }
        if isPlaying {
            synthesizer.pauseSpeaking(at: .word)
            isPlaying = false
            timer?.invalidate()
        } else if synthesizer.isPaused {
            synthesizer.continueSpeaking()
            isPlaying = true
            startTimer()
        } else {
            play(point)
        }
    }

    func seek(to value: Double) {
        guard let point else { return }
        progress = min(max(value, 0), 1)
        elapsed = point.duration * progress
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        timer?.invalidate()
        isPlaying = false
        progress = 0
        elapsed = 0
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.isPlaying = false
            self.progress = 1
            self.timer?.invalidate()
        }
    }

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, let point = self.point, self.isPlaying else { return }
                self.elapsed += 0.5
                self.progress = min(self.elapsed / point.duration, 1)
            }
        }
    }
}
