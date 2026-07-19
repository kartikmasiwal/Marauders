import Foundation

@MainActor
final class TajAIInsightStore: ObservableObject {
    enum State: Equatable {
        case idle, loading, success(String), failure(String)
    }

    @Published private(set) var states: [String: State] = [:]
    private let defaults: UserDefaults
    private let engine: any AnswerEngine

    init(defaults: UserDefaults = .standard, engine: any AnswerEngine = HybridAnswerEngine()) {
        self.defaults = defaults
        self.engine = engine
    }

    func state(for chapterID: String) -> State {
        states[chapterID] ?? .idle
    }

    func load(for chapter: TajMapCheckpoint) async {
        let key = cacheKey(chapter.id)
        if let cached = defaults.string(forKey: key), !cached.isEmpty {
            states[chapter.id] = .success(cached)
            return
        }
        states[chapter.id] = .loading
        if let live = await liveInsight(for: chapter) {
            guard !Task.isCancelled else { return }
            defaults.set(live, forKey: key)
            states[chapter.id] = .success(live)
            return
        }
        guard !Task.isCancelled else { return }
        guard !chapter.fallbackAIInformation.isEmpty else {
            states[chapter.id] = .failure("No offline guide note is available for this chapter.")
            return
        }
        defaults.set(chapter.fallbackAIInformation, forKey: key)
        states[chapter.id] = .success(chapter.fallbackAIInformation)
    }

    // Text-only /ask fast path (skipAudio) — falls back to the bundled note offline or without an app key.
    private func liveInsight(for chapter: TajMapCheckpoint) async -> String? {
        let question = "Share one fascinating, lesser-known insight about the \(chapter.name) chapter of the Taj Mahal in two sentences."
        let response = try? await engine.answer(
            text: question, audioBase64: nil,
            checkpointId: Self.backendCheckpointID(forChapter: chapter.id),
            monumentId: "taj_mahal", lang: "en", skipAudio: true
        )
        guard let text = response?.text.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else { return nil }
        return text
    }

    static func backendCheckpointID(forChapter id: String) -> String {
        backendCheckpointIDs[id] ?? "cp_great_gate"
    }

    private static let backendCheckpointIDs: [String: String] = [
        "start": "cp_great_gate",
        "great-gate": "cp_great_gate",
        "terrace": "cp_main_platform",
        "mughal-charbagh": "cp_river_view",
        "mosque": "cp_inlay_detail",
        "exit": "cp_great_gate"
    ]

    func retry(for chapter: TajMapCheckpoint) async {
        defaults.removeObject(forKey: cacheKey(chapter.id))
        await load(for: chapter)
    }

    private func cacheKey(_ chapterID: String) -> String {
        "taj.ai-insight.v1.\(chapterID)"
    }
}
