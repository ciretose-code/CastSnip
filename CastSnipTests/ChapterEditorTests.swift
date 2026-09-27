import Testing
import Foundation
@testable import CastSnip

struct ChapterVisibilityTests {

    @Test func ctocParserReadsChildIDs() {
        var body = Data("toc".utf8)
        body.append(0x00)
        body.append(0x03)
        body.append(0x02)
        body.append(contentsOf: "chp0".utf8)
        body.append(0x00)
        body.append(contentsOf: "chp2".utf8)
        body.append(0x00)

        #expect(ID3Parser.ctocChildIDs(from: body) == ["chp0", "chp2"])
    }

    @Test func missingTOCLeavesChaptersVisible() {
        let chapter = Chapter(title: "Intro", startTime: 0, endTime: 1000)
        chapter.elementID = "chp0"
        ChapterVisibility.apply(tocChildIDs: nil, to: [chapter])
        #expect(chapter.isHidden == false)
    }
}

struct TrackTimeParsingTests {

    @Test func parseTrackTimeRejectsInvalidText() {
        #expect(ID3Parser.parseTrackTime("invalid") == nil)
        #expect(ID3Parser.parseTrackTime("") == nil)
        #expect(ID3Parser.parseTrackTime("1:xx") == nil)
        #expect(ID3Parser.parseTrackTime("a:00:00") == nil)
    }

    @Test func parseTrackTimeAcceptsValidTimes() {
        #expect(ID3Parser.parseTrackTime("45") == 45_000)
        #expect(ID3Parser.parseTrackTime("1:30") == 90_000)
        #expect(ID3Parser.parseTrackTime("1:30:45") == 5_445_000)
        #expect(ID3Parser.parseTrackTime("0:00") == 0)
        #expect(ID3Parser.parseTrackTime("1:30.500") == 90_500)
    }
}

struct ChapterTimelineTests {

    @Test func insertIntoEmptyListCoversFullDuration() {
        var chapters: [Chapter] = []
        let added = ChapterTimeline.insertChapter(into: &chapters, atPlayhead: 1500, durationMillis: 10_000)

        #expect(chapters.count == 1)
        #expect(added.startTime == 0)
        #expect(added.endTime == 10_000)
        #expect(Podcast.chaptersDoNotOverlap(chapters))
    }

    @Test func insertAtPlayheadSplitsContainingChapter() {
        var chapters = [
            Chapter(title: "Intro", startTime: 0, endTime: 10_000, podcastDuration: 10_000)
        ]

        let added = ChapterTimeline.insertChapter(into: &chapters, atPlayhead: 4000, durationMillis: 10_000)

        #expect(chapters.count == 2)
        let intro = chapters.first { $0.title == "Intro" }
        #expect(intro?.endTime == 4000)
        #expect(added.startTime == 4000)
        #expect(added.endTime == 10_000)
        #expect(Podcast.chaptersDoNotOverlap(chapters))
    }

    @Test func insertBetweenTwoChaptersDoesNotOverlap() {
        var chapters = [
            Chapter(title: "A", startTime: 0, endTime: 4000, podcastDuration: 10_000),
            Chapter(title: "B", startTime: 4000, endTime: 10_000, podcastDuration: 10_000)
        ]

        let added = ChapterTimeline.insertChapter(into: &chapters, atPlayhead: 2000, durationMillis: 10_000)

        #expect(added.startTime == 2000)
        #expect(added.endTime == 4000)
        #expect(chapters.first { $0.title == "A" }?.endTime == 2000)
        #expect(chapters.first { $0.title == "B" }?.startTime == 4000)
        #expect(Podcast.chaptersDoNotOverlap(chapters))
    }

    @Test func insertAtExistingStartMovesForwardOneSecond() {
        var chapters = [
            Chapter(title: "Intro", startTime: 0, endTime: 10_000, podcastDuration: 10_000)
        ]

        let added = ChapterTimeline.insertChapter(into: &chapters, atPlayhead: 0, durationMillis: 10_000)

        #expect(added.startTime == 1000)
        #expect(chapters.first { $0.title == "Intro" }?.endTime == 1000)
        #expect(Podcast.chaptersDoNotOverlap(chapters))
    }
}
