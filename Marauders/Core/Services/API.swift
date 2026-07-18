import Foundation

enum API {
    static let azureBase = URL(string: "https://marauders-backend.azurewebsites.net")!

    static var base: URL {
        configuredURL(key: "MaraudersAPIBaseURL") ?? URL(string: "http://127.0.0.1:8000")!
    }

    static var appKey: String {
        ProcessInfo.processInfo.environment["MARAUDERS_APP_KEY"]
            ?? Bundle.main.object(forInfoDictionaryKey: "MaraudersAppKey") as? String
            ?? ""
    }

    private static func configuredURL(key: String) -> URL? {
        let environment = ProcessInfo.processInfo.environment["MARAUDERS_API_BASE_URL"]
        let plist = Bundle.main.object(forInfoDictionaryKey: key) as? String
        let value = environment ?? plist
        guard let value, !value.isEmpty, !value.contains("$(") else { return nil }
        return URL(string: value)
    }
}
