@preconcurrency import AVFoundation
import Foundation

@MainActor
final class VoiceQuestionService: NSObject, ObservableObject, AVAudioRecorderDelegate, AVAudioPlayerDelegate {
    enum State: Equatable {
        case idle
        case recording
        case thinking
        case speaking
        case failed(String)
    }

    @Published private(set) var state: State = .idle
    @Published private(set) var answerText: String?

    private var recorder: AVAudioRecorder?
    private var player: AVAudioPlayer?
    private let engine: any AnswerEngine

    init(engine: any AnswerEngine = AzureAnswerEngine()) {
        self.engine = engine
        super.init()
    }

    func toggleRecording(checkpointID: String, monumentID: String, language: String) {
        if state == .recording {
            stopAndAsk(checkpointID: checkpointID, monumentID: monumentID, language: language)
        } else {
            Task { await startRecording() }
        }
    }

    func retry(checkpointID: String, monumentID: String, language: String) {
        state = .idle
        toggleRecording(checkpointID: checkpointID, monumentID: monumentID, language: language)
    }

    private func startRecording() async {
        let allowed = await AVAudioApplication.requestRecordPermission()
        guard allowed else {
            state = .failed("Microphone access is required to ask the guide a question.")
            return
        }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .spokenAudio, options: [.defaultToSpeaker, .allowBluetoothHFP])
            try session.setActive(true)
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("question-\(UUID().uuidString).m4a")
            let settings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 16_000,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ]
            recorder = try AVAudioRecorder(url: url, settings: settings)
            recorder?.delegate = self
            recorder?.record()
            state = .recording
            answerText = nil
        } catch {
            state = .failed("The microphone could not start. Please try again.")
        }
    }

    private func stopAndAsk(checkpointID: String, monumentID: String, language: String) {
        guard let recorder else { return }
        recorder.stop()
        let url = recorder.url
        self.recorder = nil
        state = .thinking
        Task {
            do {
                let audio = try Data(contentsOf: url).base64EncodedString()
                let response = try await engine.answer(
                    text: nil, audioBase64: audio,
                    checkpointId: checkpointID, monumentId: monumentID, lang: language
                )
                answerText = response.text
                try play(base64: response.audioBase64)
            } catch {
                state = .failed(error.localizedDescription)
            }
            try? FileManager.default.removeItem(at: url)
        }
    }

    private func play(base64: String) throws {
        guard let data = Data(base64Encoded: base64) else { throw CocoaError(.fileReadCorruptFile) }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("answer-\(UUID().uuidString).mp3")
        try data.write(to: url, options: .atomic)
        player = try AVAudioPlayer(contentsOf: url)
        player?.delegate = self
        player?.prepareToPlay()
        player?.play()
        state = .speaking
    }

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in self.state = .idle }
    }
}
