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

    @Test func ensureLeadingIntroInsertsWhenMissingZeroStart() {
        var chapters = [
            Chapter(title: "Main", startTime: 5_000, endTime: 10_000, podcastDuration: 10_000)
        ]

        let inserted = ChapterTimeline.ensureLeadingIntro(into: &chapters, durationMillis: 10_000)

        #expect(inserted == true)
        #expect(chapters.map(\.title) == ["Intro", "Main"])
        #expect(chapters[0].startTime == 0)
        #expect(chapters[0].endTime == 5_000)
        #expect(chapters[1].startTime == 5_000)
        #expect(Podcast.chaptersDoNotOverlap(chapters))
    }

    @Test func ensureLeadingIntroCoversFullDurationWhenEmpty() {
        var chapters: [Chapter] = []

        let inserted = ChapterTimeline.ensureLeadingIntro(into: &chapters, durationMillis: 8_000)

        #expect(inserted == true)
        #expect(chapters.count == 1)
        #expect(chapters[0].title == "Intro")
        #expect(chapters[0].startTime == 0)
        #expect(chapters[0].endTime == 8_000)
    }

    @Test func ensureLeadingIntroLeavesExistingZeroStartAlone() {
        var chapters = [
            Chapter(title: "Cold open", startTime: 0, endTime: 2_000, podcastDuration: 10_000),
            Chapter(title: "Main", startTime: 2_000, endTime: 10_000, podcastDuration: 10_000)
        ]

        let inserted = ChapterTimeline.ensureLeadingIntro(into: &chapters, durationMillis: 10_000)

        #expect(inserted == false)
        #expect(chapters.map(\.title) == ["Cold open", "Main"])
    }

    @Test func ensureLeadingIntroSkipsWhenDurationUnknown() {
        var chapters: [Chapter] = []
        let inserted = ChapterTimeline.ensureLeadingIntro(into: &chapters, durationMillis: 0)
        #expect(inserted == false)
        #expect(chapters.isEmpty)
    }
}

struct ChapterBoundaryTests {

    private func threeChapters() -> [Chapter] {
        [
            Chapter(title: "A", startTime: 0, endTime: 4_000, podcastDuration: 12_000),
            Chapter(title: "B", startTime: 4_000, endTime: 8_000, podcastDuration: 12_000),
            Chapter(title: "C", startTime: 8_000, endTime: 12_000, podcastDuration: 12_000)
        ]
    }

    @Test func movingStartUpdatesPreviousEnd() {
        let chapters = threeChapters()
        let moved = ChapterTimeline.moveStart(of: chapters[1], to: 5_500, in: chapters, durationMillis: 12_000)

        #expect(moved == 5_500)
        #expect(chapters[1].startTime == 5_500)
        #expect(chapters[0].endTime == 5_500)
        #expect(Podcast.chaptersDoNotOverlap(chapters))
    }

    @Test func movingStartClampsBetweenNeighbors() {
        let chapters = threeChapters()
        ChapterTimeline.moveStart(of: chapters[1], to: 11_000, in: chapters, durationMillis: 12_000)
        #expect(chapters[1].startTime == 7_000)
        #expect(chapters[0].endTime == 7_000)

        ChapterTimeline.moveStart(of: chapters[1], to: 0, in: chapters, durationMillis: 12_000)
        #expect(chapters[1].startTime == 1_000)
        #expect(chapters[0].endTime == 1_000)
    }

    @Test func firstChapterStartIsLocked() {
        let chapters = threeChapters()
        let moved = ChapterTimeline.moveStart(of: chapters[0], to: 2_000, in: chapters, durationMillis: 12_000)

        #expect(moved == 0)
        #expect(chapters[0].startTime == 0)
        #expect(ChapterTimeline.isStartLocked(chapters[0], in: chapters))
        #expect(!ChapterTimeline.isStartLocked(chapters[1], in: chapters))
    }

    @Test func movingLastStartStaysBeforeDuration() {
        let chapters = threeChapters()
        ChapterTimeline.moveStart(of: chapters[2], to: 20_000, in: chapters, durationMillis: 12_000)
        #expect(chapters[2].startTime == 11_000)
        #expect(chapters[1].endTime == 11_000)
    }

    @Test func removingMiddleChapterExtendsPrevious() {
        var chapters = threeChapters()
        ChapterTimeline.removeChapter(chapters[1], from: &chapters)

        #expect(chapters.map(\.title) == ["A", "C"])
        #expect(chapters[0].endTime == 8_000)
    }

    @Test func removingFirstChapterPullsNextToStart() {
        var chapters = threeChapters()
        ChapterTimeline.removeChapter(chapters[0], from: &chapters)

        #expect(chapters.map(\.title) == ["B", "C"])
        #expect(chapters[0].startTime == 0)
    }

    @Test func chapterAtTimeFindsContainingChapter() {
        let chapters = threeChapters()
        #expect(ChapterTimeline.chapter(at: 0, in: chapters)?.title == "A")
        #expect(ChapterTimeline.chapter(at: 4_000, in: chapters)?.title == "B")
        #expect(ChapterTimeline.chapter(at: 11_999, in: chapters)?.title == "C")
    }
}
