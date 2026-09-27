import Testing
import Foundation
@testable import CastSnip

struct AircheckEdgeTests {

    @Test func chaptersToExportWithEmptyListReturnsEmpty() {
        #expect(AircheckExporter.chaptersToExport(selected: nil, all: []).isEmpty)
    }

    @Test func chaptersToExportWithNilSelectionReturnsTitledChaptersOnly() {
        let titled = Chapter(title: "Acme Ad", startTime: 0, endTime: 4_000)
        let blank = Chapter(title: "   ", startTime: 4_000, endTime: 8_000)
        let untitled = Chapter(title: "", startTime: 8_000, endTime: 12_000)
        let sponsor = Chapter(title: "Sponsor", startTime: 12_000, endTime: 16_000)

        let exported = AircheckExporter.chaptersToExport(
            selected: nil,
            all: [titled, blank, untitled, sponsor]
        )

        #expect(exported.map(\.title) == ["Acme Ad", "Sponsor"])
    }

    @Test func chaptersToExportWithMultipleSelectedReturnsThoseChaptersInTimelineOrder() {
        let titled = Chapter(title: "Acme Ad", startTime: 0, endTime: 4_000)
        let blank = Chapter(title: "   ", startTime: 4_000, endTime: 8_000)
        let sponsor = Chapter(title: "Sponsor", startTime: 12_000, endTime: 16_000)

        let exported = AircheckExporter.chaptersToExport(
            selected: [sponsor, blank],
            all: [titled, blank, sponsor]
        )

        #expect(exported.map(\.title) == ["   ", "Sponsor"])
    }

    @Test func sanitizedReplacesIllegalFilenameCharacters() {
        #expect(AircheckExporter.sanitized("Acme / Ads:30?") == "Acme - Ads-30-")
        #expect(AircheckExporter.sanitized("   ") == "chapter")
        #expect(AircheckExporter.sanitized("///") == "---")
        #expect(!AircheckExporter.sanitized("path/with/slashes").contains("/"))
    }

    @Test func filenameForChapterWithSlashTitleIsSafe() {
        let chapter = Chapter(title: "Acme / Midroll", startTime: 1_500, endTime: 3_000)
        let name = AircheckExporter.filename(for: chapter)

        #expect(!name.contains("/"))
        #expect(name.hasSuffix(".wav"))
        #expect(name.contains("1500"))
    }

    @Test func introOutsideResourcesIsNotASampleEpisode() {
        #expect(!SampleEpisode.isSample(URL(fileURLWithPath: "/tmp/intro.mp3")))
        #expect(!SampleEpisode.isSample(
            URL(fileURLWithPath: "/Applications/CastSnip.app/Contents/Resources/episode.mp3")
        ))
    }
}
