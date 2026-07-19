@preconcurrency import AVFoundation
import Foundation

@MainActor
final class AudioNarrationController: NSObject, ObservableObject {
    enum State: Equatable { case idle, speaking, pausing, paused }

    @Published private(set) var state: State = .idle
    @Published private(set) var progress: Double = 0
    @Published private(set) var elapsed: TimeInterval = 0
    @Published private(set) var estimatedDuration: TimeInterval = 0
    @Published var speechRate: Float {
        didSet { defaults.set(speechRate, forKey: rateKey) }
    }

    private let synthesizer = AVSpeechSynthesizer()
    private let defaults: UserDefaults
    private let rateKey = "taj.narration-rate.v1"
    private var activeUtterance: AVSpeechUtterance?
    private var text = ""
    private var language = "en-IN"
    private var chapterID = ""
    private var startedAt: Date?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let number = defaults.object(forKey: rateKey) as? NSNumber {
            speechRate = min(max(number.floatValue, AVSpeechUtteranceMinimumSpeechRate), AVSpeechUtteranceMaximumSpeechRate)
        } else {
            speechRate = AVSpeechUtteranceDefaultSpeechRate
        }
        super.init()
        synthesizer.delegate = self
    }

    var isSpeaking: Bool { state == .speaking || state == .pausing }

    func play(text: String, languageCode: String, chapterID: String) {
        if self.chapterID == chapterID, state == .paused {
            resume()
            return
        }
        start(text: text, languageCode: languageCode, chapterID: chapterID)
    }

    func pause() {
        guard state == .speaking, synthesizer.pauseSpeaking(at: .word) else { return }
        state = .pausing
    }

    func resume() {
        guard state == .paused else { return }
        _ = synthesizer.continueSpeaking()
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        activeUtterance = nil
        startedAt = nil
        state = .idle
        progress = 0
        elapsed = 0
    }

    func restart() {
        guard !text.isEmpty else { return }
        start(text: text, languageCode: language, chapterID: chapterID)
    }

    private func start(text: String, languageCode: String, chapterID: String) {
        synthesizer.stopSpeaking(at: .immediate)
        self.text = text
        language = locale(for: languageCode)
        self.chapterID = chapterID
        progress = 0
        elapsed = 0
        estimatedDuration = max(Double(text.split(whereSeparator: \.isWhitespace).count) / wordsPerSecond, 1)

        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: language)
        utterance.rate = speechRate
        utterance.pitchMultiplier = 0.96
        utterance.prefersAssistiveTechnologySettings = true
        utterance.postUtteranceDelay = 0.15
        activeUtterance = utterance
        startedAt = Date()
        state = .speaking
        synthesizer.speak(utterance)
    }

    private var wordsPerSecond: Double {
        let normalized = Double(speechRate / AVSpeechUtteranceDefaultSpeechRate)
        return max(2.1 * normalized, 0.8)
    }

    private func locale(for code: String) -> String {
        switch code { case "hi": "hi-IN"; case "fr": "fr-FR"; case "es": "es-ES"; default: "en-IN" }
    }

    private func updateElapsed() {
        if let startedAt { elapsed = min(Date().timeIntervalSince(startedAt), estimatedDuration) }
    }

    private func finish(_ utterance: AVSpeechUtterance) {
        guard activeUtterance === utterance else { return }
        updateElapsed()
        progress = 1
        state = .idle
        activeUtterance = nil
        startedAt = nil
    }
}

extension AudioNarrationController: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didPause utterance: AVSpeechUtterance) {
        Task { @MainActor [weak self] in
            guard let self, self.activeUtterance === utterance else { return }
            self.updateElapsed()
            self.state = .paused
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didContinue utterance: AVSpeechUtterance) {
        Task { @MainActor [weak self] in
            guard let self, self.activeUtterance === utterance else { return }
            self.startedAt = Date().addingTimeInterval(-self.elapsed)
            self.state = .speaking
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor [weak self] in self?.finish(utterance) }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor [weak self] in
            guard let self, self.activeUtterance === utterance else { return }
            self.activeUtterance = nil
            self.startedAt = nil
            self.state = .idle
        }
    }

    nonisolated func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        willSpeakRangeOfSpeechString characterRange: NSRange,
        utterance: AVSpeechUtterance
    ) {
        Task { @MainActor [weak self] in
            guard let self, self.activeUtterance === utterance, !self.text.isEmpty else { return }
            self.progress = min(Double(characterRange.location + characterRange.length) / Double(self.text.utf16.count), 1)
            self.updateElapsed()
        }
    }
}
