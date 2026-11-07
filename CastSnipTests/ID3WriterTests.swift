//
//  ID3WriterTests.swift
//  CastSnipTests
//

import Testing
import Foundation
import AppKit
import SwiftUI
@testable import CastSnip

struct ID3ParserSafetyTests {

    @Test func getDataReadsLengthBytesFromOffset() {
        var data = Data([0xAA, 0xBB, 0xCC, 0xDD, 0xEE])
        var offset = 1
        let slice = ID3Parser.getData(data, &offset, 2)
        #expect(Array(slice) == [0xBB, 0xCC])
        #expect(offset == 3)
    }

    @Test func getDataStopsAtEndOfBuffer() {
        var data = Data([0x01, 0x02])
        var offset = 1
        let slice = ID3Parser.getData(data, &offset, 50)
        #expect(Array(slice) == [0x02])
        #expect(offset == 2)
    }

    @Test func getUInt32ReturnsNilWhenTruncated() {
        var data = Data([0x00, 0x01])
        var offset = 0
        let value = ID3Parser.getUInt32(data, &offset)
        #expect(value == 0)
        #expect(offset == 0)
    }

    @Test func getTagHeaderReturnsEmptyNameWhenTruncated() {
        var data = Data([0x41, 0x42])
        var offset = 0
        let header = ID3Parser.getTagHeader(data, &offset)
        #expect(header.name.isEmpty)
        #expect(header.length == 0)
    }

    @Test func chapterInitSurvivesWXXXWithoutURLComponent() {
        var body = Data()
        body.append(contentsOf: Array("chp0".utf8))
        body.append(0x00)
        body.append(contentsOf: [0x00, 0x00, 0x03, 0xE8]) // start 1000
        body.append(contentsOf: [0x00, 0x00, 0x07, 0xD0]) // end 2000
        body.append(contentsOf: [0xFF, 0xFF, 0xFF, 0xFF])
        body.append(contentsOf: [0xFF, 0xFF, 0xFF, 0xFF])

        let wxxxBody = Data([0x00]) + Data("only-description".utf8)
        body.append(contentsOf: Array("WXXX".utf8))
        body.append(contentsOf: ID3Parser.uint32Bytes(UInt32(wxxxBody.count)))
        body.append(contentsOf: [0x00, 0x00])
        body.append(wxxxBody)

        let chapter = Chapter(data: body, podcastDuration: 10_000)
        #expect(chapter.startTime == 1000)
        #expect(chapter.endTime == 2000)
        #expect(chapter.url.isEmpty)
    }

    @Test func readFramesRejectsID3v24WithClearError() {
        var tag = Data("ID3".utf8)
        tag.append(contentsOf: [0x04, 0x00, 0x00])
        tag.append(contentsOf: ID3Parser.synchsafeBytes(0))

        var thrown: Error?
        do {
            _ = try ID3Parser.readFrames(from: tag)
        } catch {
            thrown = error
        }

        guard let parserError = thrown as? ID3ParserError else {
            Issue.record("expected ID3ParserError, got \(String(describing: thrown))")
            return
        }
        guard case .unsupportedVersion(let version) = parserError else {
            Issue.record("expected unsupportedVersion, got \(parserError)")
            return
        }
        #expect(version == 4)
        #expect(parserError.errorDescription?.contains("2.4") == true)
    }

    @Test func readFramesThrowsWhenTagMissing() {
        var thrown: Error?
        do {
            _ = try ID3Parser.readFrames(from: Data([0xFF, 0xFB, 0x90, 0x00]))
        } catch {
            thrown = error
        }
        #expect(thrown is ID3ParserError)
        if let parserError = thrown as? ID3ParserError {
            guard case .missingTag = parserError else {
                Issue.record("expected missingTag, got \(parserError)")
                return
            }
        }
    }

    @Test func getStringReadsNullTerminatedText() {
        var data = Data([0x00])
        data.append(contentsOf: "Hello".utf8)
        data.append(0x00)
        data.append(contentsOf: "rest".utf8)
        var offset = 0
        #expect(ID3Parser.getString(data, &offset) == "Hello")
        #expect(offset == 7)
    }

    @Test func getStringHonorsDeclaredLengthAndStopsAtBufferEnd() {
        var data = Data([0x00])
        data.append(contentsOf: "Title".utf8)
        var offset = 0
        #expect(ID3Parser.getString(data, &offset, length: 4) == "Tit")
        #expect(offset == 4)

        offset = 0
        let truncated = ID3Parser.getString(Data([0x03, 0x41]), &offset, length: 80)
        #expect(truncated == "A")
        #expect(offset == 2)
    }

    @Test func chapterInitReadsTIT2AndWXXXFromCHAP() {
        var body = chapFrameBody(id: "chp0", start: 1000, end: 4000)
        body.append(id3Subframe("TIT2", Data([0x00]) + Data("Intro".utf8)))
        body.append(id3Subframe("WXXX", Data([0x00, 0x00]) + Data("https://example.com/intro".utf8)))

        let chapter = Chapter(data: body, podcastDuration: 10_000)
        #expect(chapter.elementID == "chp0")
        #expect(chapter.title == "Intro")
        #expect(chapter.url == "https://example.com/intro")
        #expect(chapter.startTime == 1000)
        #expect(chapter.endTime == 4000)
    }

    @Test func chapterInitSurvivesTruncatedCHAP() {
        let truncated = Data("chp0".utf8) + Data([0x00, 0x00, 0x03])
        let chapter = Chapter(data: truncated, podcastDuration: 10_000)
        #expect(chapter.elementID == "chp0")
        #expect(chapter.startTime == 0)
        #expect(chapter.endTime == 0)
        #expect(chapter.title.isEmpty)
        #expect(chapter.url.isEmpty)
        #expect(chapter.image == nil)
    }

    @Test func chapterInitSurvivesTruncatedWXXXFrame() {
        var body = chapFrameBody(id: "chp1", start: 0, end: 500)
        body.append(contentsOf: Array("WXXX".utf8))
        body.append(contentsOf: ID3Parser.uint32Bytes(40))
        body.append(contentsOf: [0x00, 0x00])
        body.append(0x00)

        let chapter = Chapter(data: body, podcastDuration: 10_000)
        #expect(chapter.startTime == 0)
        #expect(chapter.endTime == 500)
        #expect(chapter.url.isEmpty)
    }

    @Test func chapterInitSurvivesTruncatedAPICFrame() {
        var body = chapFrameBody(id: "chp2", start: 10, end: 20)
        body.append(contentsOf: Array("APIC".utf8))
        body.append(contentsOf: ID3Parser.uint32Bytes(200))
        body.append(contentsOf: [0x00, 0x00])
        body.append(contentsOf: [0x00])
        body.append(contentsOf: Array("im".utf8))

        let chapter = Chapter(data: body, podcastDuration: 10_000)
        #expect(chapter.startTime == 10)
        #expect(chapter.endTime == 20)
        #expect(chapter.image == nil)
    }

    @Test func chapterInitReadsAPICImage() throws {
        let jpeg = try #require(ID3Writer.jpegData(from: makeSolidJPEGImage()))
        var apicBody = Data([0x00])
        apicBody.append(contentsOf: Array("image/jpeg".utf8))
        apicBody.append(0x00)
        apicBody.append(0x03)
        apicBody.append(0x00)
        apicBody.append(jpeg)

        var body = chapFrameBody(id: "chp3", start: 0, end: 1000)
        body.append(id3Subframe("APIC", apicBody))

        let chapter = Chapter(data: body, podcastDuration: 10_000)
        #expect(chapter.image != nil)
        #expect((chapter.image?.size.width ?? 0) > 0)
    }
}

struct PodcastValidationTests {

    @Test func validateChaptersEmptyListIsValid() {
        let podcast = Podcast()
        #expect(podcast.validateChapters())
    }

    @Test func validateChaptersSingleChapterIsValid() {
        let podcast = Podcast()
        podcast.chapters = [Chapter(title: "Only", startTime: 0, endTime: 1000)]
        #expect(podcast.validateChapters())
    }

    @Test func validateChaptersDetectsOverlap() {
        let podcast = Podcast()
        podcast.chapters = [
            Chapter(title: "A", startTime: 0, endTime: 2000),
            Chapter(title: "B", startTime: 1000, endTime: 3000)
        ]
        #expect(!podcast.validateChapters())
    }
}

struct ID3MetadataMappingTests {

    @Test func talbMapsToShowTitle() {
        let podcast = Podcast()
        ID3MetadataMapping.applyString(key: "TALB", value: "Mostly Security", to: podcast)
        #expect(podcast.title == "Mostly Security")
    }

    @Test func tit2MapsToEpisodeTitle() {
        let podcast = Podcast()
        ID3MetadataMapping.applyString(key: "TIT2", value: "329: Cool", to: podcast)
        #expect(podcast.episode == "329: Cool")
    }

    @Test func tpe1DoesNotOverwriteShowTitle() {
        let podcast = Podcast()
        ID3MetadataMapping.applyString(key: "TALB", value: "Mostly Security", to: podcast)
        ID3MetadataMapping.applyString(key: "TPE1", value: "Eric", to: podcast)
        #expect(podcast.title == "Mostly Security")
        #expect(podcast.artist == "Eric")
    }

    @Test func commMapsToSummary() {
        let podcast = Podcast()
        ID3MetadataMapping.applyString(key: "COMM", value: "Show notes", to: podcast)
        #expect(podcast.summary == "Show notes")
    }

    @Test func usltDoesNotReplaceExistingSummary() {
        let podcast = Podcast()
        ID3MetadataMapping.applyString(key: "COMM", value: "Show notes", to: podcast)
        ID3MetadataMapping.applyString(key: "USLT", value: "Lyrics", to: podcast)
        #expect(podcast.summary == "Show notes")
    }
}

struct ID3WriterTests {

    @Test func mpegAudioPayloadSkipsExistingID3Tag() {
        var tag = Data("ID3".utf8)
        tag.append(contentsOf: [0x03, 0x00, 0x00])
        tag.append(contentsOf: ID3Parser.synchsafeBytes(10))
        tag.append(Data(repeating: 0, count: 10))
        let audio = Data([0xFF, 0xFB, 0x90, 0x00, 0x01, 0x02, 0x03])
        let payload = ID3Writer.mpegAudioPayload(from: tag + audio)
        #expect(payload == audio)
    }

    @Test func mpegAudioPayloadIsWholeFileWhenNoTag() {
        let audio = Data([0xFF, 0xFB, 0x90, 0x00])
        #expect(ID3Writer.mpegAudioPayload(from: audio) == audio)
    }

    @Test func taggedMP3WritesShowEpisodeAndSummary() throws {
        let podcast = Podcast()
        podcast.title = "Mostly Security"
        podcast.episode = "329: Cool"
        podcast.summary = "Notes"
        podcast.durationInMillis = 12_000

        let mp3 = ID3Writer.taggedMP3(from: Data([0xFF, 0xFB, 0x90, 0x00]), podcast: podcast)
        let frames = try ID3Parser.readFrames(from: mp3)
        let texts = Dictionary(uniqueKeysWithValues: frames.compactMap { frame -> (String, String)? in
            guard ["TALB", "TIT2", "COMM", "TLEN"].contains(frame.name) else { return nil }
            return (frame.name, ID3Parser.decodeTextFrameBody(frame.body))
        })

        #expect(texts["TALB"] == "Mostly Security")
        #expect(texts["TIT2"] == "329: Cool")
        #expect(texts["COMM"]?.contains("Notes") == true)
        #expect(texts["TLEN"] == "12000")
    }

    @Test func taggedMP3WritesYearAndCastSetEncoder() throws {
        let podcast = Podcast()
        podcast.year = "2024"

        let mp3 = ID3Writer.taggedMP3(from: Data([0xFF, 0xFB, 0x90, 0x00]), podcast: podcast)
        let frames = try ID3Parser.readFrames(from: mp3)
        let texts = Dictionary(uniqueKeysWithValues: frames.compactMap { frame -> (String, String)? in
            guard ["TYER", "TENC"].contains(frame.name) else { return nil }
            return (frame.name, ID3Parser.decodeTextFrameBody(frame.body))
        })

        #expect(texts["TYER"] == "2024")
        #expect(texts["TENC"] == Podcast.castSetEncoder)
        #expect(Podcast.castSetEncoder == "CastSet by ciretose")
    }

    @Test func ensureDefaultYearFillsCurrentYearWhenEmpty() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let date = calendar.date(from: DateComponents(year: 2025, month: 6, day: 1))!
        var year = ""
        let inserted = Podcast.ensureDefaultYear(&year, now: date, calendar: calendar)
        #expect(inserted == true)
        #expect(year == "2025")
    }

    @Test func ensureDefaultYearKeepsExistingValue() {
        var year = "2019"
        let inserted = Podcast.ensureDefaultYear(&year)
        #expect(inserted == false)
        #expect(year == "2019")
    }

    @Test func taggedMP3WritesChaptersAndTOCThatParserCanRead() throws {
        let podcast = Podcast()
        podcast.durationInMillis = 10_000
        podcast.chapters = [
            Chapter(title: "Intro", url: "https://example.com/intro", startTime: 0, endTime: 4000, podcastDuration: 10_000),
            Chapter(title: "Interview", url: "", startTime: 4000, endTime: 10_000, podcastDuration: 10_000)
        ]

        let mp3 = ID3Writer.taggedMP3(from: Data([0xFF, 0xFB, 0x90, 0x00]), podcast: podcast)
        let frames = try ID3Parser.readFrames(from: mp3)
        let chapBodies = frames.filter { $0.name == "CHAP" }.map(\.body)
        #expect(chapBodies.count == 2)

        let chapters = chapBodies.map { Chapter(data: $0, podcastDuration: 10_000) }.sorted()
        #expect(chapters[0].title.contains("Intro"))
        #expect(chapters[0].url == "https://example.com/intro")
        #expect(chapters[0].startTime == 0)
        #expect(chapters[0].endTime == 4000)
        #expect(chapters[1].title.contains("Interview"))
        #expect(chapters[1].startTime == 4000)

        #expect(frames.contains { $0.name == "CTOC" })
    }

    @Test func hiddenChaptersAreWrittenButOmittedFromTOC() throws {
        let hidden = Chapter(title: "Sponsor art", startTime: 2000, endTime: 4000, podcastDuration: 10_000, isHidden: true)
        let visible = Chapter(title: "Intro", startTime: 0, endTime: 2000, podcastDuration: 10_000)
        let podcast = Podcast()
        podcast.durationInMillis = 10_000
        podcast.chapters = [visible, hidden]

        let mp3 = ID3Writer.taggedMP3(from: Data([0xFF, 0xFB, 0x90, 0x00]), podcast: podcast)
        let frames = try ID3Parser.readFrames(from: mp3)
        #expect(frames.filter { $0.name == "CHAP" }.count == 2)

        let toc = frames.first { $0.name == "CTOC" }
        #expect(toc != nil)
        let childIDs = ID3Parser.ctocChildIDs(from: toc!.body)
        #expect(childIDs == ["chp0"])

        let parsed = frames.filter { $0.name == "CHAP" }.map { Chapter(data: $0.body, podcastDuration: 10_000) }
        ChapterVisibility.apply(tocChildIDs: childIDs, to: parsed)
        #expect(parsed.first { $0.title.contains("Intro") }?.isHidden == false)
        #expect(parsed.first { $0.title.contains("Sponsor") }?.isHidden == true)
    }

    @Test func taggedMP3WritesCoverArt() throws {
        let podcast = Podcast()
        podcast.title = "Art Show"
        podcast.logo = makeSolidJPEGImage()

        let mp3 = ID3Writer.taggedMP3(from: Data([0xFF, 0xFB, 0x90, 0x00]), podcast: podcast)
        let frames = try ID3Parser.readFrames(from: mp3)
        let apic = frames.first { $0.name == "APIC" }
        #expect(apic != nil)
        #expect(apic!.body.count > 20)
        #expect(apic!.body.contains(0xFF) && apic!.body.contains(0xD8))
    }

    @Test func writeReplacesDestinationFile() throws {
        let source = FileManager.default.temporaryDirectory.appendingPathComponent("castsnip-source-\(UUID().uuidString).mp3")
        let dest = FileManager.default.temporaryDirectory.appendingPathComponent("castsnip-dest-\(UUID().uuidString).mp3")
        defer {
            try? FileManager.default.removeItem(at: source)
            try? FileManager.default.removeItem(at: dest)
        }

        try Data([0xFF, 0xFB, 0x90, 0x00, 0x11, 0x22]).write(to: source)
        let podcast = Podcast()
        podcast.title = "Written"
        podcast.episode = "Ep"
        podcast.url = source

        try ID3Writer.write(podcast: podcast, from: source, to: dest)

        let written = try Data(contentsOf: dest)
        let frames = try ID3Parser.readFrames(from: written)
        #expect(frames.contains { $0.name == "TALB" && ID3Parser.decodeTextFrameBody($0.body) == "Written" })
        #expect(ID3Writer.mpegAudioPayload(from: written).starts(with: [0xFF, 0xFB]))
    }

    @Test func writeOmitsAllTagsWhenIncludeTagsIsFalse() throws {
        let source = FileManager.default.temporaryDirectory.appendingPathComponent("castsnip-notags-src-\(UUID().uuidString).mp3")
        let dest = FileManager.default.temporaryDirectory.appendingPathComponent("castsnip-notags-dest-\(UUID().uuidString).mp3")
        defer {
            try? FileManager.default.removeItem(at: source)
            try? FileManager.default.removeItem(at: dest)
        }

        try Data([0xFF, 0xFB, 0x90, 0x00, 0x11, 0x22]).write(to: source)
        let podcast = Podcast()
        podcast.title = "Should Not Appear"
        podcast.logo = makeSolidJPEGImage()
        podcast.chapters = [Chapter(title: "Intro", startTime: 0, endTime: 1000, podcastDuration: 1000)]
        podcast.url = source

        try ID3Writer.write(podcast: podcast, from: source, to: dest, includeTags: false)

        let written = try Data(contentsOf: dest)
        #expect(!written.starts(with: Data("ID3".utf8)))
        #expect(written == Data([0xFF, 0xFB, 0x90, 0x00, 0x11, 0x22]))
    }

    @Test func saveThenReopenPreservesTitleChaptersAndArtwork() throws {
        let source = FileManager.default.temporaryDirectory.appendingPathComponent("castsnip-roundtrip-src-\(UUID().uuidString).mp3")
        let dest = FileManager.default.temporaryDirectory.appendingPathComponent("castsnip-roundtrip-dest-\(UUID().uuidString).mp3")
        defer {
            try? FileManager.default.removeItem(at: source)
            try? FileManager.default.removeItem(at: dest)
        }

        try Data([0xFF, 0xFB, 0x90, 0x00, 0x11, 0x22]).write(to: source)

        let podcast = Podcast()
        podcast.title = "Mostly Security"
        podcast.episode = "329: Cool"
        podcast.durationInMillis = 10_000
        podcast.logo = makeSolidJPEGImage()
        podcast.chapters = [
            Chapter(title: "Intro", url: "https://example.com/intro", startTime: 0, endTime: 4000, podcastDuration: 10_000),
            Chapter(title: "Interview", url: "", startTime: 4000, endTime: 10_000, podcastDuration: 10_000)
        ]
        podcast.url = source

        try ID3Writer.write(podcast: podcast, from: source, to: dest)

        let reopened = try Data(contentsOf: dest)
        let frames = try ID3Parser.readFrames(from: reopened)
        let texts = Dictionary(uniqueKeysWithValues: frames.compactMap { frame -> (String, String)? in
            guard ["TALB", "TIT2"].contains(frame.name) else { return nil }
            return (frame.name, ID3Parser.decodeTextFrameBody(frame.body))
        })
        #expect(texts["TALB"] == "Mostly Security")
        #expect(texts["TIT2"] == "329: Cool")

        let chapters = frames.filter { $0.name == "CHAP" }.map { Chapter(data: $0.body, podcastDuration: 10_000) }.sorted()
        #expect(chapters.count == 2)
        #expect(chapters[0].title.contains("Intro"))
        #expect(chapters[0].url == "https://example.com/intro")
        #expect(chapters[0].startTime == 0)
        #expect(chapters[0].endTime == 4000)
        #expect(chapters[1].title.contains("Interview"))
        #expect(chapters[1].startTime == 4000)

        let apic = frames.first { $0.name == "APIC" }
        #expect(apic != nil)
        #expect(apic?.body.contains(0xFF) == true && apic?.body.contains(0xD8) == true)
    }
}

@MainActor
struct AudioFileLoadSaveTests {

    @Test func loadPodcastReadsTaggedTempMP3() async throws {
        let (url, cleanup) = try writeTaggedTempPodcast()
        defer { cleanup() }

        let audioFile = AudioFile()
        await audioFile.loadPodcast(from: url)

        #expect(audioFile.podcast.url == url)
        #expect(audioFile.podcast.asset != nil)
        #expect(audioFile.podcast.title == "Load Show")
        #expect(audioFile.podcast.episode == "Load Episode")
        #expect(audioFile.podcast.chapters.count == 2)
        #expect(audioFile.podcast.chapters.sorted()[0].title.contains("Cold open"))
        #expect(audioFile.podcast.chapters.sorted()[1].title.contains("Main"))
        #expect(audioFile.podcast.year == "2024")
        #expect(audioFile.podcast.logo != nil)
        #expect(audioFile.errorMessage == nil)
        #expect(!audioFile.hasUnsavedChanges)
        #expect(!audioFile.isLoading)
    }

    @Test func loadPodcastMissingFileSetsError() async {
        let missing = FileManager.default.temporaryDirectory
            .appendingPathComponent("castsnip-missing-\(UUID().uuidString).mp3")

        let audioFile = AudioFile()
        await audioFile.loadPodcast(from: missing)

        #expect(audioFile.errorMessage != nil)
        #expect(audioFile.podcast.file == nil)
        #expect(audioFile.podcast.chapters.isEmpty)
        #expect(!audioFile.isLoading)
    }

    @Test func loadPodcastUnknownDurationSetsWarning() async throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("castsnip-noduration-\(UUID().uuidString).mp3")
        defer { try? FileManager.default.removeItem(at: url) }
        try Data("not an mpeg audio stream".utf8).write(to: url)

        let audioFile = AudioFile()
        await audioFile.loadPodcast(from: url)

        #expect(audioFile.podcast.durationInSeconds == 0)
        #expect(audioFile.errorMessage?.localizedCaseInsensitiveContains("duration") == true)
    }

    @Test func saveThenLoadPodcastPreservesTitleChaptersAndArtwork() async throws {
        let (source, cleanupSource) = try writeTaggedTempPodcast()
        let dest = FileManager.default.temporaryDirectory
            .appendingPathComponent("castsnip-save-reopen-\(UUID().uuidString).mp3")
        defer {
            cleanupSource()
            try? FileManager.default.removeItem(at: dest)
        }

        let audioFile = AudioFile()
        await audioFile.loadPodcast(from: source)
        audioFile.podcast.title = "Edited Show"
        audioFile.podcast.episode = "Edited Episode"
        try audioFile.save(to: dest)

        let reopened = AudioFile()
        await reopened.loadPodcast(from: dest)

        #expect(reopened.podcast.title == "Edited Show")
        #expect(reopened.podcast.episode == "Edited Episode")
        #expect(reopened.podcast.chapters.count == 2)
        #expect(reopened.podcast.chapters.sorted()[0].title.contains("Cold open"))
        #expect(reopened.podcast.logo != nil)
        #expect(!reopened.hasUnsavedChanges)
    }
}

struct AudioFileDirtyStateTests {

    @Test func editingTitleMarksUnsavedChanges() {
        let audioFile = AudioFile()
        #expect(!audioFile.hasUnsavedChanges)

        var title = audioFile.getTitle()
        title.wrappedValue = "Changed"
        #expect(audioFile.hasUnsavedChanges)
        #expect(audioFile.podcast.title == "Changed")
    }

    @Test func markAsSavedClearsUnsavedChanges() {
        let audioFile = AudioFile()
        audioFile.markAsModified()
        audioFile.markAsSaved()
        #expect(!audioFile.hasUnsavedChanges)
    }

    @Test func bundledSampleCannotBeSavedInPlace() {
        let audioFile = AudioFile()
        let bundled = URL(fileURLWithPath: "/Applications/CastSnip.app/Contents/Resources/intro.mp3")
        audioFile.podcast.url = bundled
        #expect(!audioFile.canSaveInPlace(to: bundled))
    }
}

private func makeSolidJPEGImage() -> NSImage {
    let image = NSImage(size: NSSize(width: 2, height: 2))
    image.lockFocus()
    NSColor.red.setFill()
    NSBezierPath(rect: NSRect(x: 0, y: 0, width: 2, height: 2)).fill()
    image.unlockFocus()
    return image
}

private func chapFrameBody(id: String, start: UInt32, end: UInt32) -> Data {
    var body = Data(id.utf8)
    body.append(0x00)
    body.append(contentsOf: ID3Parser.uint32Bytes(start))
    body.append(contentsOf: ID3Parser.uint32Bytes(end))
    body.append(contentsOf: [0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF])
    return body
}

private func id3Subframe(_ name: String, _ body: Data) -> Data {
    var data = Data(name.utf8)
    data.append(contentsOf: ID3Parser.uint32Bytes(UInt32(body.count)))
    data.append(contentsOf: [0x00, 0x00])
    data.append(body)
    return data
}

private func sampleAudioURL() -> URL? {
    if let bundled = Bundle(for: AudioFile.self).url(forResource: "intro", withExtension: "mp3") {
        return bundled
    }
    let fromSource = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appendingPathComponent("CastSnip/Samples/intro.mp3")
    return FileManager.default.fileExists(atPath: fromSource.path) ? fromSource : nil
}

private func writeTaggedTempPodcast() throws -> (URL, () -> Void) {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("castsnip-load-\(UUID().uuidString).mp3")
    let audio: Data
    if let sample = sampleAudioURL(), let data = try? Data(contentsOf: sample) {
        audio = data
    } else {
        audio = Data([0xFF, 0xFB, 0x90, 0x00, 0x11, 0x22, 0x33, 0x44])
    }

    let podcast = Podcast()
    podcast.title = "Load Show"
    podcast.episode = "Load Episode"
    podcast.year = "2024"
    podcast.durationInMillis = 10_000
    podcast.logo = makeSolidJPEGImage()
    podcast.chapters = [
        Chapter(title: "Cold open", url: "https://example.com/cold", startTime: 0, endTime: 2000, podcastDuration: 10_000),
        Chapter(title: "Main", url: "", startTime: 2000, endTime: 10_000, podcastDuration: 10_000)
    ]

    try ID3Writer.taggedMP3(from: audio, podcast: podcast).write(to: url)
    return (url, { try? FileManager.default.removeItem(at: url) })
}
