import Foundation
import Testing
@testable import Marauders

struct MaraudersTests {
    @Test @MainActor func bundledPackageInstallsAndValidates() async throws {
        let store = PackageStore()
        let installed = try await store.prepare(monumentID: "taj_mahal", preferBundled: true)

        #expect(installed.package.schemaVersion == 1)
        #expect(installed.package.monument.id == "taj_mahal")
        #expect(installed.package.checkpoints.count == 3)
        for checkpoint in installed.package.checkpoints {
            for path in checkpoint.introAudio.values {
                #expect(FileManager.default.fileExists(atPath: installed.fileURL(for: path).path))
            }
            for nugget in checkpoint.nuggets {
                #expect(FileManager.default.fileExists(atPath: installed.targetURL(for: nugget).path))
                #expect(nugget.audio.values.allSatisfy { FileManager.default.fileExists(atPath: installed.fileURL(for: $0).path) })
            }
        }
    }

    @Test func languageFallbackUsesEnglish() {
        let values: LangMap = ["en": "Gateway", "hi": "द्वार"]
        #expect(values.v("hi") == "द्वार")
        #expect(values.v("fr") == "Gateway")
    }

    @Test func audioDebounceMatchesContract() {
        #expect(AudioTiming.enterHold == 0.3)
        #expect(AudioTiming.exitHold == 1.5)
        #expect(AudioTiming.fadeIn == 0.4)
        #expect(AudioTiming.fadeOut == 0.6)
        #expect(AudioTiming.crossfade == 0.5)
    }
}
