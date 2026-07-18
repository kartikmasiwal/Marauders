import Foundation

protocol AnswerEngine {
    func answer(
        text: String?, audioBase64: String?,
        checkpointId: String, monumentId: String, lang: String
    ) async throws -> AskResponse
}

struct AskResponse: Codable {
    let question: String
    let text: String
    let audioBase64: String
}

private struct AskRequest: Encodable {
    let monumentId: String
    let checkpointId: String
    let lang: String
    let text: String?
    let audioBase64: String?
}

struct AzureAnswerEngine: AnswerEngine {
    enum EngineError: LocalizedError {
        case missingAppKey
        case invalidResponse
        case server(String)

        var errorDescription: String? {
            switch self {
            case .missingAppKey: "Live questions are not configured on this build. Add MARAUDERS_APP_KEY locally."
            case .invalidResponse: "The guide returned an unreadable response. Please try again."
            case .server(let message): message
            }
        }
    }

    let session: URLSession

    init(session: URLSession = .shared) { self.session = session }

    func answer(
        text: String?, audioBase64: String?,
        checkpointId: String, monumentId: String, lang: String
    ) async throws -> AskResponse {
        guard !API.appKey.isEmpty else { throw EngineError.missingAppKey }
        var request = URLRequest(url: API.base.appendingPathComponent("ask"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(API.appKey, forHTTPHeaderField: "X-App-Key")
        request.timeoutInterval = 20
        request.httpBody = try JSONEncoder().encode(AskRequest(
            monumentId: monumentId, checkpointId: checkpointId, lang: lang,
            text: text, audioBase64: audioBase64
        ))

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw EngineError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else {
            throw EngineError.server("The live guide is unavailable (\(http.statusCode)). Please retry.")
        }
        return try JSONDecoder().decode(AskResponse.self, from: data)
    }

    func health() async -> Bool {
        do {
            let (_, response) = try await session.data(from: API.base.appendingPathComponent("health"))
            return (response as? HTTPURLResponse)?.statusCode == 200
        } catch { return false }
    }
}

struct FoundationModelsAnswerEngine: AnswerEngine {
    func answer(
        text: String?, audioBase64: String?,
        checkpointId: String, monumentId: String, lang: String
    ) async throws -> AskResponse {
        throw CocoaError(.featureUnsupported, userInfo: [NSLocalizedDescriptionKey: "On-device Q&A requires the iOS 27 FoundationModels SDK."])
    }
}
