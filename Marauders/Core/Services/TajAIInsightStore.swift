import Foundation

@MainActor
final class TajAIInsightStore: ObservableObject {
    enum State: Equatable {
        case idle, loading, success(String), failure(String)
    }

    @Published private(set) var states: [String: State] = [:]
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
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
        try? await Task.sleep(for: .milliseconds(350))
        guard !Task.isCancelled else { return }
        guard !chapter.fallbackAIInformation.isEmpty else {
            states[chapter.id] = .failure("No offline guide note is available for this chapter.")
            return
        }
        defaults.set(chapter.fallbackAIInformation, forKey: key)
        states[chapter.id] = .success(chapter.fallbackAIInformation)
    }

    func retry(for chapter: TajMapCheckpoint) async {
        defaults.removeObject(forKey: cacheKey(chapter.id))
        await load(for: chapter)
    }

    private func cacheKey(_ chapterID: String) -> String {
        "taj.ai-insight.v1.\(chapterID)"
    }
}
