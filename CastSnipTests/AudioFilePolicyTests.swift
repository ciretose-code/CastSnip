import Testing
import Foundation
@testable import CastSnip

struct AudioFilePolicyTests {

    @Test func cannotSaveInPlaceWhenURLIsNil() {
        let audioFile = AudioFile()
        #expect(!audioFile.canSaveInPlace(to: nil))
    }

    @Test func cannotSaveInPlaceInsideContentsResources() {
        let audioFile = AudioFile()
        let bundled = URL(fileURLWithPath: "/Applications/CastSnip.app/Contents/Resources/intro.mp3")
        #expect(!audioFile.canSaveInPlace(to: bundled))
    }

    @Test func canSaveInPlaceToATempPathOutsideTheBundle() {
        let audioFile = AudioFile()
        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent("castsnip-policy-\(UUID().uuidString).mp3")
        #expect(audioFile.canSaveInPlace(to: temp))
    }

    @Test func closeDocumentClearsSelectionErrorDirtyFlagAndChapters() {
        let audioFile = AudioFile()
        let chapter = Chapter(title: "Intro", startTime: 0, endTime: 4_000)
        audioFile.podcast.chapters = [chapter]
        audioFile.selectedChapter = chapter
        audioFile.errorMessage = "Failed to load audio file."
        audioFile.markAsModified()

        audioFile.closeDocument()

        #expect(audioFile.selectedChapter == nil)
        #expect(audioFile.errorMessage == nil)
        #expect(audioFile.hasUnsavedChanges == false)
        #expect(audioFile.podcast.chapters.isEmpty)
    }

    @Test func selectNeighborMovesNextAndPreviousAcrossThreeChapters() {
        let audioFile = AudioFile()
        let intro = Chapter(title: "Intro", startTime: 0, endTime: 4_000)
        let ads = Chapter(title: "Ads", startTime: 4_000, endTime: 8_000)
        let talk = Chapter(title: "Talk", startTime: 8_000, endTime: 12_000)
        audioFile.podcast.chapters = [intro, ads, talk]
        audioFile.selectedChapter = intro

        audioFile.selectNeighbor(going: .next)
        #expect(audioFile.selectedChapter === ads)

        audioFile.selectNeighbor(going: .next)
        #expect(audioFile.selectedChapter === talk)

        audioFile.selectNeighbor(going: .previous)
        #expect(audioFile.selectedChapter === ads)

        audioFile.selectNeighbor(going: .previous)
        #expect(audioFile.selectedChapter === intro)
    }
}
