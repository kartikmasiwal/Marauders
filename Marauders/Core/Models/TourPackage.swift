import Foundation

typealias LangMap = [String: String]

extension LangMap {
    func v(_ lang: String) -> String { self[lang] ?? self["en"] ?? "" }
    func mediaPath(_ lang: String) -> String { self[lang] ?? self["en"] ?? values.first ?? "" }
}

struct TourPackage: Codable {
    let schemaVersion: Int
    let monument: Monument
    let routes: Routes?
    let checkpoints: [Checkpoint]
}

struct Monument: Codable {
    let id: String
    let name: LangMap
    let languages: [String]
    let overview: LangMap
    let ambientTrack: String?
}

struct Routes: Codable { let monument: Route?; let venue: Route? }
struct Route: Codable { let start: String; let end: String }

struct Checkpoint: Codable, Identifiable {
    let id: String
    let order: Int
    let name: LangMap
    let mapPosition: MapPosition
    let gps: GPS?
    let venue: Bool
    let intro: LangMap
    let introAudio: LangMap
    let nuggets: [Nugget]
}

struct MapPosition: Codable { let x: Double; let y: Double }
struct GPS: Codable { let lat: Double; let lng: Double; let radius: Double }

struct Nugget: Codable, Identifiable {
    let id: String
    let title: LangMap
    let targetImageId: String
    let exclusive: Bool
    let text: LangMap
    let audio: LangMap
}

struct InstalledTour {
    let package: TourPackage
    let directory: URL

    func fileURL(for relativePath: String) -> URL {
        directory.appendingPathComponent(relativePath)
    }

    func targetURL(for nugget: Nugget) -> URL {
        directory.appendingPathComponent("targets/\(nugget.targetImageId).jpg")
    }
}
