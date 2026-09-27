import Testing
import Foundation
@testable import CastSnip

struct AudioMarkerImporterTests {

    @Test func labeledWavCuePointsBecomeChapters() throws {
        let wav = WAVMarkerFixture.file(
            sampleRate: 8_000,
            frames: 8_000,
            cues: [
                .init(id: 1, sample: 0, label: "Intro"),
                .init(id: 2, sample: 4_000, label: "Interview"),
            ],
            includeLabels: true
        )
        let url = try writeTemp(wav, ext: "wav")
        defer { try? FileManager.default.removeItem(at: url) }

        let chapters = AudioMarkerImporter.chapters(from: url, durationMillis: 1_000)

        #expect(chapters.map(\.title) == ["Intro", "Interview"])
        #expect(chapters.map(\.startTime) == [0, 500])
        #expect(chapters.map(\.endTime) == [500, 1_000])
        #expect(chapters.allSatisfy { $0.podcastDuration == 1_000 })
    }

    @Test func unlabeledWavCuePointsBecomeNumberedMarkers() throws {
        let wav = WAVMarkerFixture.file(
            sampleRate: 8_000,
            frames: 8_000,
            cues: [
                .init(id: 10, sample: 2_000, label: nil),
                .init(id: 11, sample: 0, label: nil),
            ],
            includeLabels: false
        )
        let url = try writeTemp(wav, ext: "wav")
        defer { try? FileManager.default.removeItem(at: url) }

        let chapters = AudioMarkerImporter.chapters(from: url, durationMillis: 2_000)

        #expect(chapters.map(\.title) == ["Marker 1", "Marker 2"])
        #expect(chapters.map(\.startTime) == [0, 250])
        #expect(chapters.map(\.endTime) == [250, 2_000])
    }

    @Test func wavWithoutCuePointsReturnsNoChapters() throws {
        let wav = WAVMarkerFixture.file(sampleRate: 8_000, frames: 800, cues: [], includeLabels: false)
        let url = try writeTemp(wav, ext: "wav")
        defer { try? FileManager.default.removeItem(at: url) }

        let chapters = AudioMarkerImporter.chapters(from: url, durationMillis: 100)
        #expect(chapters.isEmpty)
    }

    @Test func labeledAiffMarkersBecomeChapters() throws {
        let aiff = AIFFMarkerFixture.file(
            sampleRate: 8_000,
            frames: 8_000,
            markers: [
                .init(id: 1, sample: 0, name: "Cold open"),
                .init(id: 2, sample: 4_000, name: "Credits"),
            ]
        )
        let url = try writeTemp(aiff, ext: "aiff")
        defer { try? FileManager.default.removeItem(at: url) }

        let chapters = AudioMarkerImporter.chapters(from: url, durationMillis: 1_000)

        #expect(chapters.map(\.title) == ["Cold open", "Credits"])
        #expect(chapters.map(\.startTime) == [0, 500])
        #expect(chapters.map(\.endTime) == [500, 1_000])
    }

    @Test func m4aWithoutChapterMetadataReturnsEmpty() throws {
        let url = try writeTemp(Data("not a real movie file".utf8), ext: "m4a")
        defer { try? FileManager.default.removeItem(at: url) }

        let chapters = AudioMarkerImporter.chapters(from: url, durationMillis: 5_000)
        #expect(chapters.isEmpty)
    }

    @Test @MainActor
    func loadPodcastImportsWavMarkersWhenID3ChaptersAreAbsent() async throws {
        let wav = WAVMarkerFixture.file(
            sampleRate: 8_000,
            frames: 8_000,
            cues: [
                .init(id: 1, sample: 0, label: "Cold open"),
                .init(id: 2, sample: 4_000, label: "Main"),
            ],
            includeLabels: true
        )
        let url = try writeTemp(wav, ext: "wav")
        defer { try? FileManager.default.removeItem(at: url) }

        let audioFile = AudioFile()
        await audioFile.loadPodcast(from: url)

        #expect(audioFile.podcast.asset != nil)
        #expect(audioFile.podcast.chapters.map(\.title) == ["Cold open", "Main"])
        #expect(audioFile.podcast.chapters.map(\.startTime) == [0, 500])
    }

    @Test @MainActor
    func loadPodcastLeavesEmptyChaptersWhenWavHasNoMarkers() async throws {
        let wav = WAVMarkerFixture.file(sampleRate: 8_000, frames: 8_000, cues: [], includeLabels: false)
        let url = try writeTemp(wav, ext: "wav")
        defer { try? FileManager.default.removeItem(at: url) }

        let audioFile = AudioFile()
        await audioFile.loadPodcast(from: url)

        #expect(audioFile.podcast.asset != nil)
        #expect(audioFile.podcast.chapters.isEmpty)
        #expect(audioFile.errorMessage == nil)
    }

    @Test @MainActor
    func loadPodcastStillReportsCorruptFiles() async {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("castsnip-corrupt-\(UUID().uuidString).wav")
        try? Data([0x00, 0x01, 0x02, 0x03]).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        let audioFile = AudioFile()
        await audioFile.loadPodcast(from: url)

        #expect(audioFile.errorMessage != nil)
        #expect(audioFile.podcast.chapters.isEmpty)
    }
}

private func writeTemp(_ data: Data, ext: String) throws -> URL {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("castsnip-markers-\(UUID().uuidString).\(ext)")
    try data.write(to: url)
    return url
}

private enum WAVMarkerFixture {
    struct Cue {
        var id: UInt32
        var sample: UInt32
        var label: String?
    }

    static func file(sampleRate: UInt32, frames: UInt32, cues: [Cue], includeLabels: Bool) -> Data {
        var body = Data()
        body.append(chunk("fmt ", payload: fmtChunk(sampleRate: sampleRate)))
        body.append(chunk("data", payload: Data(count: Int(frames) * 2)))

        if !cues.isEmpty {
            var cuePayload = Data()
            cuePayload.append(le32(UInt32(cues.count)))
            for cue in cues {
                cuePayload.append(le32(cue.id))
                cuePayload.append(le32(cue.sample))
                cuePayload.append(contentsOf: Array("data".utf8))
                cuePayload.append(le32(0))
                cuePayload.append(le32(0))
                cuePayload.append(le32(cue.sample))
            }
            body.append(chunk("cue ", payload: cuePayload))

            if includeLabels {
                var adtl = Data(Array("adtl".utf8))
                for cue in cues {
                    guard let label = cue.label else { continue }
                    var name = Data(label.utf8)
                    name.append(0)
                    var labl = Data()
                    labl.append(le32(cue.id))
                    labl.append(name)
                    adtl.append(chunk("labl", payload: labl))
                }
                body.append(chunk("LIST", payload: adtl))
            }
        }

        var riff = Data()
        riff.append(contentsOf: Array("RIFF".utf8))
        riff.append(le32(UInt32(4 + body.count)))
        riff.append(contentsOf: Array("WAVE".utf8))
        riff.append(body)
        return riff
    }

    private static func fmtChunk(sampleRate: UInt32) -> Data {
        var data = Data()
        data.append(le16(1))
        data.append(le16(1))
        data.append(le32(sampleRate))
        data.append(le32(sampleRate * 2))
        data.append(le16(2))
        data.append(le16(16))
        return data
    }

    private static func chunk(_ id: String, payload: Data) -> Data {
        var data = Data(Array(id.utf8))
        data.append(le32(UInt32(payload.count)))
        data.append(payload)
        if payload.count % 2 == 1 {
            data.append(0)
        }
        return data
    }
}

private enum AIFFMarkerFixture {
    struct Marker {
        var id: Int16
        var sample: UInt32
        var name: String
    }

    static func file(sampleRate: UInt32, frames: UInt32, markers: [Marker]) -> Data {
        var body = Data()
        body.append(chunk("COMM", payload: commChunk(sampleRate: sampleRate, frames: frames)))

        var ssnd = Data()
        ssnd.append(be32(0))
        ssnd.append(be32(0))
        ssnd.append(Data(count: Int(frames) * 2))
        body.append(chunk("SSND", payload: ssnd))

        var mark = Data()
        mark.append(be16(UInt16(markers.count)))
        for marker in markers {
            mark.append(be16(UInt16(bitPattern: marker.id)))
            mark.append(be32(marker.sample))
            mark.append(pascalString(marker.name))
        }
        body.append(chunk("MARK", payload: mark))

        var form = Data()
        form.append(contentsOf: Array("FORM".utf8))
        form.append(be32(UInt32(4 + body.count)))
        form.append(contentsOf: Array("AIFF".utf8))
        form.append(body)
        return form
    }

    private static func commChunk(sampleRate: UInt32, frames: UInt32) -> Data {
        var data = Data()
        data.append(be16(1))
        data.append(be32(frames))
        data.append(be16(16))
        data.append(extended80(sampleRate))
        return data
    }

    private static func chunk(_ id: String, payload: Data) -> Data {
        var data = Data(Array(id.utf8))
        data.append(be32(UInt32(payload.count)))
        data.append(payload)
        if payload.count % 2 == 1 {
            data.append(0)
        }
        return data
    }

    private static func pascalString(_ string: String) -> Data {
        let bytes = Array(string.utf8)
        var data = Data([UInt8(bytes.count)])
        data.append(contentsOf: bytes)
        if data.count % 2 == 1 {
            data.append(0)
        }
        return data
    }

    /// 80-bit IEEE extended used by AIFF COMM sample rates.
    private static func extended80(_ value: UInt32) -> Data {
        if value == 0 {
            return Data(count: 10)
        }
        var n = value
        var shift: Int = 31
        while shift > 0, (n & (1 << shift)) == 0 {
            shift -= 1
        }
        let exponent = UInt16(shift + 16383)
        let mantissa = UInt64(n) << (63 - shift)
        var data = Data()
        data.append(UInt8(exponent >> 8))
        data.append(UInt8(exponent & 0xff))
        for i in stride(from: 56, through: 0, by: -8) {
            data.append(UInt8((mantissa >> UInt64(i)) & 0xff))
        }
        return data
    }
}

private func le16(_ value: UInt16) -> Data {
    var value = value.littleEndian
    return Data(bytes: &value, count: 2)
}

private func le32(_ value: UInt32) -> Data {
    var value = value.littleEndian
    return Data(bytes: &value, count: 4)
}

private func be16(_ value: UInt16) -> Data {
    var value = value.bigEndian
    return Data(bytes: &value, count: 2)
}

private func be32(_ value: UInt32) -> Data {
    var value = value.bigEndian
    return Data(bytes: &value, count: 4)
}
