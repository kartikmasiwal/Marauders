import Foundation
import ZIPFoundation

@MainActor
final class PackageStore: ObservableObject {
    enum PackageError: LocalizedError {
        case missingBundledPackage(String)
        case invalidResponse
        case invalidPackage(String)

        var errorDescription: String? {
            switch self {
            case .missingBundledPackage(let id): "No bundled package is available for \(id). Connect to download it."
            case .invalidResponse: "The tour package server returned an invalid response."
            case .invalidPackage(let reason): "The tour package is incomplete: \(reason)"
            }
        }
    }

    @Published private(set) var downloadProgress: Double = 0
    @Published private(set) var isDownloading = false

    private let fileManager: FileManager
    private let session: URLSession

    init(fileManager: FileManager = .default, session: URLSession = .shared) {
        self.fileManager = fileManager
        self.session = session
    }

    func installedTour(monumentID: String) throws -> InstalledTour? {
        let directory = try packageDirectory(monumentID: monumentID)
        guard fileManager.fileExists(atPath: directory.appendingPathComponent("tour.json").path) else { return nil }
        return try decodeAndValidate(directory: directory)
    }

    func prepare(monumentID: String, preferBundled: Bool = true) async throws -> InstalledTour {
        if let installed = try installedTour(monumentID: monumentID) { return installed }
        isDownloading = true
        downloadProgress = 0
        defer { isDownloading = false }

        let archiveURL: URL
        if preferBundled, let bundled = Bundle.main.url(forResource: monumentID, withExtension: "zip") {
            archiveURL = bundled
            downloadProgress = 0.35
        } else {
            archiveURL = try await download(monumentID: monumentID)
            downloadProgress = 0.65
        }

        let destination = try packageDirectory(monumentID: monumentID)
        try? fileManager.removeItem(at: destination)
        try fileManager.createDirectory(at: destination, withIntermediateDirectories: true)
        try fileManager.unzipItem(at: archiveURL, to: destination)
        downloadProgress = 1
        return try decodeAndValidate(directory: destination)
    }

    func remove(monumentID: String) throws {
        try fileManager.removeItem(at: packageDirectory(monumentID: monumentID))
    }

    private func download(monumentID: String) async throws -> URL {
        let url = API.base.appendingPathComponent("packages/\(monumentID).zip")
        let (temporaryURL, response) = try await session.download(from: url)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { throw PackageError.invalidResponse }
        let destination = fileManager.temporaryDirectory.appendingPathComponent("\(monumentID)-\(UUID().uuidString).zip")
        try fileManager.moveItem(at: temporaryURL, to: destination)
        return destination
    }

    private func packageDirectory(monumentID: String) throws -> URL {
        let root = try fileManager.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent("TourPackages", isDirectory: true)
        try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
        return root.appendingPathComponent(monumentID, isDirectory: true)
    }

    private func decodeAndValidate(directory: URL) throws -> InstalledTour {
        let data = try Data(contentsOf: directory.appendingPathComponent("tour.json"))
        let tourPackage = try JSONDecoder().decode(TourPackage.self, from: data)
        guard !tourPackage.checkpoints.isEmpty else { throw PackageError.invalidPackage("no checkpoints") }

        for checkpoint in tourPackage.checkpoints {
            guard !checkpoint.nuggets.isEmpty else { throw PackageError.invalidPackage("\(checkpoint.id) has no nuggets") }
            for path in checkpoint.introAudio.values where !fileManager.fileExists(atPath: directory.appendingPathComponent(path).path) {
                throw PackageError.invalidPackage("missing \(path)")
            }
            for nugget in checkpoint.nuggets {
                for path in nugget.audio.values where !fileManager.fileExists(atPath: directory.appendingPathComponent(path).path) {
                    throw PackageError.invalidPackage("missing \(path)")
                }
                let target = directory.appendingPathComponent("targets/\(nugget.targetImageId).jpg")
                guard fileManager.fileExists(atPath: target.path) else {
                    throw PackageError.invalidPackage("missing targets/\(nugget.targetImageId).jpg")
                }
            }
        }
        return InstalledTour(package: tourPackage, directory: directory)
    }
}
