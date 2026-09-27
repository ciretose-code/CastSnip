import Testing
import Foundation
import AVFoundation
import AppKit
@testable import CastSnip

struct SilenceDetectorTests {

    @Test func defaultThresholdsMatchForecastStyleGaps() {
        #expect(SilenceDetector.defaultThresholdDb == -40)
        #expect(SilenceDetector.defaultDurationSeconds == 3)
    }

    @Test func mergesConsecutiveSilentWindowsLongerThanThreshold() {
        let windows = [
            SilenceDetector.Window(start: 0, end: 1, peakDb: -50),
            SilenceDetector.Window(start: 1, end: 2, peakDb: -45),
            SilenceDetector.Window(start: 2, end: 3, peakDb: -12),
            SilenceDetector.Window(start: 3, end: 7, peakDb: -60),
        ]

        let ranges = SilenceDetector.ranges(in: windows)

        #expect(ranges == [SilenceDetector.Range(start: 3, end: 7)])
    }

    @Test func ignoresSilenceShorterThanDuration() {
        let windows = [
            SilenceDetector.Window(start: 0, end: 1.5, peakDb: -80),
            SilenceDetector.Window(start: 1.5, end: 2.5, peakDb: -12),
        ]

        #expect(SilenceDetector.ranges(in: windows).isEmpty)
    }

    @Test func treatsPeakAtThresholdAsNotSilent() {
        let windows = [
            SilenceDetector.Window(start: 0, end: 5, peakDb: -40),
        ]

        #expect(SilenceDetector.ranges(in: windows).isEmpty)
    }

    @Test func respectsCustomThresholdAndDuration() {
        let windows = [
            SilenceDetector.Window(start: 0, end: 1, peakDb: -30),
        ]

        #expect(SilenceDetector.ranges(in: windows, thresholdDb: -20, durationSeconds: 0.5) == [
            SilenceDetector.Range(start: 0, end: 1),
        ])
        #expect(SilenceDetector.ranges(in: windows, thresholdDb: -40, durationSeconds: 0.5).isEmpty)
    }

    @Test func warningMessageIsNilWhenNoRanges() {
        #expect(SilenceDetector.warningMessage(for: []) == nil)
    }

    @Test func warningMessageListsLongGaps() {
        let message = SilenceDetector.warningMessage(for: [
            SilenceDetector.Range(start: 10, end: 16),
        ])

        #expect(message?.contains("10") == true)
        #expect(message?.contains("16") == true)
        #expect(message?.contains("6") == true)
    }

    @Test func detectFindsLongSilenceInSyntheticWAV() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("castsnip-silence-\(UUID().uuidString).wav")
        defer { try? FileManager.default.removeItem(at: url) }

        try ProductionAudioFixtures.writeWAV(to: url, duration: 1.2) { index, _ in
            index < 44_100 ? 0 : 0.4
        }

        let file = try AVAudioFile(forReading: url)
        let ranges = try SilenceDetector.detect(in: file, thresholdDb: -40, durationSeconds: 0.6)

        #expect(ranges.count == 1)
        #expect(ranges[0].duration >= 0.6)
        #expect(ranges[0].start < 0.2)
    }
}

struct PodcastEncoderTests {

    @Test func preferredToolIsInProcessLAME() {
        #expect(PodcastEncoder.preferredTool() == .lameInProcess)
    }

    @Test func defaultEncodeWritesMP3ViaInProcessLAME() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("castsnip-encode-mp3-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let input = directory.appendingPathComponent("tone.wav")
        try ProductionAudioFixtures.writeSineWAV(to: input, duration: 0.4)
        let requested = directory.appendingPathComponent("episode.mp3")

        var progressValues: [Double] = []
        let written = try await PodcastEncoder.encode(
            from: input,
            to: requested,
            progress: { progressValues.append($0) }
        )

        #expect(written.pathExtension == "mp3")
        #expect(FileManager.default.fileExists(atPath: written.path))
        let data = try Data(contentsOf: written)
        #expect(data.count > 128)
        #expect(progressValues.contains { $0 == 0 || $0 > 0 })
        #expect(progressValues.contains { $0 >= 1 })
        #expect(progressValues.allSatisfy { $0 >= 0 && $0 <= 1 })
    }

    @Test func defaultEncodeFallsBackToAACWhenLAMEThrows() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("castsnip-encode-lame-fail-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let input = directory.appendingPathComponent("tone.wav")
        try ProductionAudioFixtures.writeSineWAV(to: input, duration: 0.4)
        let requested = directory.appendingPathComponent("episode.mp3")

        var progressValues: [Double] = []
        let written = try await PodcastEncoder.encode(
            from: input,
            to: requested,
            includeTags: false,
            encoder: { _, _, _ in
                throw PodcastEncoder.EncodeError.failed("injected LAME failure")
            },
            progress: { progressValues.append($0) }
        )

        #expect(written.pathExtension == "m4a")
        #expect(FileManager.default.fileExists(atPath: written.path))
        #expect(progressValues.contains { $0 == 0 || $0 > 0 })
        #expect(progressValues.contains { $0 >= 1 })
        #expect(progressValues.allSatisfy { $0 >= 0 && $0 <= 1 })
    }

    @Test func aacFallbackWritesM4AAndReportsProgress() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("castsnip-encode-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let input = directory.appendingPathComponent("tone.wav")
        try ProductionAudioFixtures.writeSineWAV(to: input, duration: 0.4)
        let requested = directory.appendingPathComponent("episode.mp3")

        var progressValues: [Double] = []
        let written = try await PodcastEncoder.encode(
            from: input,
            to: requested,
            using: .aacM4A,
            progress: { progressValues.append($0) }
        )

        #expect(written.pathExtension == "m4a")
        #expect(FileManager.default.fileExists(atPath: written.path))
        #expect(progressValues.contains { $0 == 0 || $0 > 0 })
        #expect(progressValues.contains { $0 >= 1 })
        #expect(progressValues.allSatisfy { $0 >= 0 && $0 <= 1 })
    }

    @Test func lameEncodeWritesShowChaptersAndImages() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("castsnip-encode-tags-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let input = directory.appendingPathComponent("tone.wav")
        try ProductionAudioFixtures.writeSineWAV(to: input, duration: 0.4)
        let requested = directory.appendingPathComponent("episode.mp3")

        let cover = encodeTestImage(NSColor.red)
        let chapterArt = encodeTestImage(NSColor.blue)
        let podcast = Podcast()
        podcast.title = "Mostly Security"
        podcast.episode = "329: Cool"
        podcast.artist = "Ciretose"
        podcast.summary = "Show notes"
        podcast.durationInMillis = 400
        podcast.logo = cover
        let intro = Chapter(title: "Intro", url: "https://example.com/intro", startTime: 0, endTime: 200, podcastDuration: 400)
        intro.image = chapterArt
        podcast.chapters = [
            intro,
            Chapter(title: "Interview", startTime: 200, endTime: 400, podcastDuration: 400),
        ]

        let written = try await PodcastEncoder.encode(from: input, to: requested, tagging: podcast)

        let frames = try ID3Parser.readFrames(from: Data(contentsOf: written))
        let texts = Dictionary(uniqueKeysWithValues: frames.compactMap { frame -> (String, String)? in
            guard ["TALB", "TIT2", "TPE1"].contains(frame.name) else { return nil }
            return (frame.name, ID3Parser.decodeTextFrameBody(frame.body))
        })
        #expect(texts["TALB"] == "Mostly Security")
        #expect(texts["TIT2"] == "329: Cool")
        #expect(texts["TPE1"] == "Ciretose")
        #expect(frames.contains { $0.name == "APIC" })
        #expect(frames.contains { $0.name == "CTOC" })

        let chapters = frames.filter { $0.name == "CHAP" }.map { Chapter(data: $0.body, podcastDuration: 400) }.sorted()
        #expect(chapters.map(\.title) == ["Intro", "Interview"])
        #expect(chapters[0].url == "https://example.com/intro")
        #expect(chapters[0].image != nil)
        #expect(chapters[1].startTime == 200)
    }

    @Test func lameEncodeOmitsTagsWhenAsked() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("castsnip-encode-notags-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let input = directory.appendingPathComponent("tone.wav")
        try ProductionAudioFixtures.writeSineWAV(to: input, duration: 0.4)
        let requested = directory.appendingPathComponent("episode.mp3")

        let podcast = Podcast()
        podcast.title = "Should Not Appear"
        podcast.chapters = [Chapter(title: "Intro", startTime: 0, endTime: 400, podcastDuration: 400)]

        let written = try await PodcastEncoder.encode(
            from: input,
            to: requested,
            tagging: podcast,
            includeTags: false
        )
        let data = try Data(contentsOf: written)
        #expect(data.count > 128)
        #expect(!data.starts(with: Data("ID3".utf8)))
    }
}

struct AircheckExporterTests {

    @Test func exportsOnlyTheSelectedChapterWhenOneIsSelected() {
        let selected = Chapter(title: "Acme Ad", startTime: 4_000, endTime: 8_000)
        let other = Chapter(title: "Talk", startTime: 8_000, endTime: 12_000)

        let exported = AircheckExporter.chaptersToExport(selected: selected, all: [selected, other])
        #expect(exported.count == 1)
        #expect(exported[0] === selected)
    }

    @Test func exportsEveryTitledChapterWhenNothingIsSelected() {
        let ad = Chapter(title: "Acme Ad", startTime: 0, endTime: 4_000)
        let untitled = Chapter(title: "   ", startTime: 4_000, endTime: 8_000)
        let sponsor = Chapter(title: "Sponsor", startTime: 8_000, endTime: 12_000)

        let exported = AircheckExporter.chaptersToExport(selected: nil, all: [ad, untitled, sponsor])

        #expect(exported.map(\.title) == ["Acme Ad", "Sponsor"])
    }

    @Test func filenameUsesSanitizedTitleAndStartTime() {
        let chapter = Chapter(title: "Acme / Ads:30?", startTime: 12_000, endTime: 18_000)
        let name = AircheckExporter.filename(for: chapter)

        #expect(!name.contains("/"))
        #expect(!name.contains(":"))
        #expect(!name.contains("?"))
        #expect(name.contains("12000"))
        #expect(name.hasSuffix(".wav"))
    }

    @Test func writesOneWAVPerChapterTimeRange() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("castsnip-aircheck-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let source = directory.appendingPathComponent("source.wav")
        try ProductionAudioFixtures.writeSineWAV(to: source, duration: 2)

        let chapter = Chapter(title: "Midroll", startTime: 500, endTime: 1_500)
        let urls = try await AircheckExporter.export(
            from: source,
            chapters: [chapter],
            to: directory
        )

        #expect(urls.count == 1)
        #expect(FileManager.default.fileExists(atPath: urls[0].path))

        let exported = try AVAudioFile(forReading: urls[0])
        let seconds = Double(exported.length) / exported.processingFormat.sampleRate
        #expect(abs(seconds - 1.0) < 0.15)
    }
}

private func encodeTestImage(_ color: NSColor) -> NSImage {
    let image = NSImage(size: NSSize(width: 2, height: 2))
    image.lockFocus()
    color.setFill()
    NSBezierPath(rect: NSRect(x: 0, y: 0, width: 2, height: 2)).fill()
    image.unlockFocus()
    return image
}

enum ProductionAudioFixtures {
    static func writeSineWAV(to url: URL, duration: TimeInterval, sampleRate: Double = 44_100) throws {
        try writeWAV(to: url, duration: duration, sampleRate: sampleRate) { index, rate in
            Float(sin(2 * Double.pi * 440 * Double(index) / rate))
        }
    }

    static func writeWAV(
        to url: URL,
        duration: TimeInterval,
        sampleRate: Double = 44_100,
        sample: (Int, Double) -> Float
    ) throws {
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        let file = try AVAudioFile(forWriting: url, settings: format.settings)
        let frameCount = AVAudioFrameCount(duration * sampleRate)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!
        buffer.frameLength = frameCount
        let channel = buffer.floatChannelData![0]
        for index in 0..<Int(frameCount) {
            channel[index] = sample(index, sampleRate)
        }
        try file.write(from: buffer)
    }
}
