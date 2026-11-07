import Testing
import Foundation
@testable import CastSnip

struct AudioMarkerImporterTests {

    @Test func labeledWavCuePointsBecomeChapters() async throws {
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

        let chapters = try await AudioMarkerImporter.chapters(from: url, durationMillis: 1_000)

        #expect(chapters.map(\.title) == ["Intro", "Interview"])
        #expect(chapters.map(\.startTime) == [0, 500])
        #expect(chapters.map(\.endTime) == [500, 1_000])
        #expect(chapters.allSatisfy { $0.podcastDuration == 1_000 })
    }

    @Test func unlabeledWavCuePointsBecomeNumberedMarkers() async throws {
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

        let chapters = try await AudioMarkerImporter.chapters(from: url, durationMillis: 2_000)

        #expect(chapters.map(\.title) == ["Marker 1", "Marker 2"])
        #expect(chapters.map(\.startTime) == [0, 250])
        #expect(chapters.map(\.endTime) == [250, 2_000])
    }

    @Test func wavWithoutCuePointsReturnsNoChapters() async throws {
        let wav = WAVMarkerFixture.file(sampleRate: 8_000, frames: 800, cues: [], includeLabels: false)
        let url = try writeTemp(wav, ext: "wav")
        defer { try? FileManager.default.removeItem(at: url) }

        let chapters = try await AudioMarkerImporter.chapters(from: url, durationMillis: 100)
        #expect(chapters.isEmpty)
    }

    @Test func labeledAiffMarkersBecomeChapters() async throws {
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

        let chapters = try await AudioMarkerImporter.chapters(from: url, durationMillis: 1_000)

        #expect(chapters.map(\.title) == ["Cold open", "Credits"])
        #expect(chapters.map(\.startTime) == [0, 500])
        #expect(chapters.map(\.endTime) == [500, 1_000])
    }

    @Test func m4aWithoutChapterMetadataReturnsEmpty() async throws {
        let url = try writeTemp(Data("not a real movie file".utf8), ext: "m4a")
        defer { try? FileManager.default.removeItem(at: url) }

        let chapters = try await AudioMarkerImporter.chapters(from: url, durationMillis: 5_000)
        #expect(chapters.isEmpty)
    }

    @Test func labeledIXMLSyncPointsBecomeChaptersWhenCueChunkIsAbsent() async throws {
        let wav = IXMLMarkerFixture.file(
            sampleRate: 8_000,
            frames: 8_000,
            markers: [
                .init(sample: 0, comment: "Intro"),
                .init(sample: 4_000, comment: "Interview"),
            ]
        )
        let url = try writeTemp(wav, ext: "wav")
        defer { try? FileManager.default.removeItem(at: url) }

        let chapters = try await AudioMarkerImporter.chapters(from: url, durationMillis: 1_000)

        #expect(chapters.map(\.title) == ["Intro", "Interview"])
        #expect(chapters.map(\.startTime) == [0, 500])
        #expect(chapters.map(\.endTime) == [500, 1_000])
        #expect(chapters.allSatisfy { $0.podcastDuration == 1_000 })
    }

    @Test func unlabeledIXMLSyncPointsBecomeNumberedMarkers() async throws {
        let wav = IXMLMarkerFixture.file(
            sampleRate: 8_000,
            frames: 8_000,
            markers: [
                .init(sample: 2_000, comment: nil),
                .init(sample: 0, comment: nil),
            ]
        )
        let url = try writeTemp(wav, ext: "wav")
        defer { try? FileManager.default.removeItem(at: url) }

        let chapters = try await AudioMarkerImporter.chapters(from: url, durationMillis: 2_000)

        #expect(chapters.map(\.title) == ["Marker 1", "Marker 2"])
        #expect(chapters.map(\.startTime) == [0, 250])
        #expect(chapters.map(\.endTime) == [250, 2_000])
    }

    @Test func cuePointsArePreferredWhenIXMLMarkersAreAlsoPresent() async throws {
        let wav = IXMLMarkerFixture.file(
            sampleRate: 8_000,
            frames: 8_000,
            markers: [
                .init(sample: 0, comment: "iXML Intro"),
            ],
            cues: [
                .init(id: 1, sample: 0, label: "Cue Intro"),
                .init(id: 2, sample: 4_000, label: "Cue Main"),
            ]
        )
        let url = try writeTemp(wav, ext: "wav")
        defer { try? FileManager.default.removeItem(at: url) }

        let chapters = try await AudioMarkerImporter.chapters(from: url, durationMillis: 1_000)

        #expect(chapters.map(\.title) == ["Cue Intro", "Cue Main"])
        #expect(chapters.map(\.startTime) == [0, 500])
    }

    @Test func rf64CuePointsBecomeChaptersWhenDataSizeIs64Bit() async throws {
        let rf64 = RF64MarkerFixture.file(
            sampleRate: 8_000,
            frames: 8_000,
            cues: [
                .init(id: 1, sample: 0, label: "Intro"),
                .init(id: 2, sample: 4_000, label: "Interview"),
            ],
            includeLabels: true
        )
        let url = try writeTemp(rf64, ext: "wav")
        defer { try? FileManager.default.removeItem(at: url) }

        let chapters = try await AudioMarkerImporter.chapters(from: url, durationMillis: 1_000)

        #expect(chapters.map(\.title) == ["Intro", "Interview"])
        #expect(chapters.map(\.startTime) == [0, 500])
        #expect(chapters.map(\.endTime) == [500, 1_000])
    }

    @Test func rf64IXMLMarkersBecomeChapters() async throws {
        let rf64 = RF64MarkerFixture.file(
            sampleRate: 8_000,
            frames: 8_000,
            cues: [],
            includeLabels: false,
            ixmlMarkers: [
                .init(sample: 0, comment: "Cold open"),
                .init(sample: 4_000, comment: "Credits"),
            ]
        )
        let url = try writeTemp(rf64, ext: "wav")
        defer { try? FileManager.default.removeItem(at: url) }

        let chapters = try await AudioMarkerImporter.chapters(from: url, durationMillis: 1_000)

        #expect(chapters.map(\.title) == ["Cold open", "Credits"])
        #expect(chapters.map(\.startTime) == [0, 500])
    }

    @Test func rf64WithoutMarkersReturnsNoChapters() async throws {
        let rf64 = RF64MarkerFixture.file(
            sampleRate: 8_000,
            frames: 800,
            cues: [],
            includeLabels: false
        )
        let url = try writeTemp(rf64, ext: "wav")
        defer { try? FileManager.default.removeItem(at: url) }

        let chapters = try await AudioMarkerImporter.chapters(from: url, durationMillis: 100)
        #expect(chapters.isEmpty)
    }

    @Test func rf64WithoutDs64FailsWithClearError() async throws {
        let rf64 = RF64MarkerFixture.file(
            sampleRate: 8_000,
            frames: 8_000,
            cues: [
                .init(id: 1, sample: 0, label: "Intro"),
            ],
            includeLabels: true,
            includeDs64: false
        )
        let url = try writeTemp(rf64, ext: "wav")
        defer { try? FileManager.default.removeItem(at: url) }

        await #expect(throws: AudioMarkerImporter.Error.self) {
            try await AudioMarkerImporter.chapters(from: url, durationMillis: 1_000)
        }
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
    func loadPodcastInsertsIntroWhenWavHasNoMarkers() async throws {
        let wav = WAVMarkerFixture.file(sampleRate: 8_000, frames: 8_000, cues: [], includeLabels: false)
        let url = try writeTemp(wav, ext: "wav")
        defer { try? FileManager.default.removeItem(at: url) }

        let audioFile = AudioFile()
        await audioFile.loadPodcast(from: url)

        #expect(audioFile.podcast.asset != nil)
        #expect(audioFile.podcast.chapters.map(\.title) == ["Intro"])
        #expect(audioFile.podcast.chapters.first?.startTime == 0)
        #expect(audioFile.hasUnsavedChanges)
        #expect(audioFile.errorMessage == nil)
    }

    @Test @MainActor
    func loadPodcastInsertsIntroBeforeMarkersThatSkipZero() async throws {
        let wav = WAVMarkerFixture.file(
            sampleRate: 8_000,
            frames: 8_000,
            cues: [
                .init(id: 1, sample: 4_000, label: "Main"),
            ],
            includeLabels: true
        )
        let url = try writeTemp(wav, ext: "wav")
        defer { try? FileManager.default.removeItem(at: url) }

        let audioFile = AudioFile()
        await audioFile.loadPodcast(from: url)

        #expect(audioFile.podcast.chapters.map(\.title) == ["Intro", "Main"])
        #expect(audioFile.podcast.chapters.map(\.startTime) == [0, 500])
        #expect(audioFile.hasUnsavedChanges)
    }

    @Test @MainActor
    func loadPodcastImportsIXMLMarkersWhenID3ChaptersAreAbsent() async throws {
        let wav = IXMLMarkerFixture.file(
            sampleRate: 8_000,
            frames: 8_000,
            markers: [
                .init(sample: 0, comment: "Cold open"),
                .init(sample: 4_000, comment: "Main"),
            ]
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
    func loadPodcastReportsUnreadableRF64MarkersAndLeavesFileOpen() async throws {
        let rf64 = RF64MarkerFixture.file(
            sampleRate: 8_000,
            frames: 8_000,
            cues: [
                .init(id: 1, sample: 0, label: "Intro"),
            ],
            includeLabels: true,
            includeDs64: false
        )
        let url = try writeTemp(rf64, ext: "wav")
        defer { try? FileManager.default.removeItem(at: url) }

        let audioFile = AudioFile()
        await audioFile.loadPodcast(from: url)

        #expect(audioFile.podcast.asset != nil)
        // RF64 opens as an asset but AVAudioFile can't read it, so no Intro is inserted.
        #expect(audioFile.podcast.chapters.isEmpty)
        #expect(audioFile.errorMessage?.localizedCaseInsensitiveContains("rf64") == true)
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
            body.append(cueChunks(cues, includeLabels: includeLabels))
        }

        var riff = Data()
        riff.append(contentsOf: Array("RIFF".utf8))
        riff.append(le32(UInt32(4 + body.count)))
        riff.append(contentsOf: Array("WAVE".utf8))
        riff.append(body)
        return riff
    }

    static func cueChunks(_ cues: [Cue], includeLabels: Bool) -> Data {
        var body = Data()
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
        return body
    }

    static func fmtChunk(sampleRate: UInt32) -> Data {
        var data = Data()
        data.append(le16(1))
        data.append(le16(1))
        data.append(le32(sampleRate))
        data.append(le32(sampleRate * 2))
        data.append(le16(2))
        data.append(le16(16))
        return data
    }

    static func chunk(_ id: String, payload: Data) -> Data {
        var data = Data(Array(id.utf8))
        data.append(le32(UInt32(payload.count)))
        data.append(payload)
        if payload.count % 2 == 1 {
            data.append(0)
        }
        return data
    }
}

private enum IXMLMarkerFixture {
    struct Marker {
        var sample: UInt64
        var comment: String?
    }

    static func file(
        sampleRate: UInt32,
        frames: UInt32,
        markers: [Marker],
        cues: [WAVMarkerFixture.Cue] = []
    ) -> Data {
        var body = Data()
        body.append(WAVMarkerFixture.chunk("fmt ", payload: WAVMarkerFixture.fmtChunk(sampleRate: sampleRate)))
        body.append(WAVMarkerFixture.chunk("data", payload: Data(count: Int(frames) * 2)))

        if !cues.isEmpty {
            body.append(WAVMarkerFixture.cueChunks(cues, includeLabels: true))
        }

        body.append(WAVMarkerFixture.chunk("iXML", payload: Data(xml(markers).utf8)))

        var riff = Data()
        riff.append(contentsOf: Array("RIFF".utf8))
        riff.append(le32(UInt32(4 + body.count)))
        riff.append(contentsOf: Array("WAVE".utf8))
        riff.append(body)
        return riff
    }

    static func xml(_ markers: [Marker]) -> String {
        let points = markers.map { marker in
            let low = UInt32(truncatingIfNeeded: marker.sample)
            let high = UInt32(marker.sample >> 32)
            let comment = marker.comment.map { "<SYNC_POINT_COMMENT>\($0)</SYNC_POINT_COMMENT>" } ?? ""
            return """
            <SYNC_POINT>
              <SYNC_POINT_LOW>\(low)</SYNC_POINT_LOW>
              <SYNC_POINT_HIGH>\(high)</SYNC_POINT_HIGH>
              \(comment)
            </SYNC_POINT>
            """
        }.joined()
        return """
        <?xml version="1.0" encoding="UTF-8"?>
        <BWFXML>
          <IXML_VERSION>1.5</IXML_VERSION>
          <SYNC_POINT_LIST>
            <SYNC_POINT_COUNT>\(markers.count)</SYNC_POINT_COUNT>
            \(points)
          </SYNC_POINT_LIST>
        </BWFXML>
        """
    }
}

private enum RF64MarkerFixture {
    static func file(
        sampleRate: UInt32,
        frames: UInt32,
        cues: [WAVMarkerFixture.Cue],
        includeLabels: Bool,
        includeDs64: Bool = true,
        ixmlMarkers: [IXMLMarkerFixture.Marker] = []
    ) -> Data {
        let dataPayload = Data(count: Int(frames) * 2)
        var afterDs64 = Data()
        afterDs64.append(WAVMarkerFixture.chunk("fmt ", payload: WAVMarkerFixture.fmtChunk(sampleRate: sampleRate)))
        afterDs64.append(contentsOf: Array("data".utf8))
        afterDs64.append(le32(0xFFFF_FFFF))
        afterDs64.append(dataPayload)
        if dataPayload.count % 2 == 1 {
            afterDs64.append(0)
        }
        if !cues.isEmpty {
            afterDs64.append(WAVMarkerFixture.cueChunks(cues, includeLabels: includeLabels))
        }
        if !ixmlMarkers.isEmpty {
            afterDs64.append(WAVMarkerFixture.chunk("iXML", payload: Data(IXMLMarkerFixture.xml(ixmlMarkers).utf8)))
        }

        var ds64 = Data()
        if includeDs64 {
            var payload = Data()
            let riffSize = UInt64(4 + 8 + 28 + afterDs64.count)
            payload.append(le64(riffSize))
            payload.append(le64(UInt64(dataPayload.count)))
            payload.append(le64(UInt64(frames)))
            payload.append(le32(0))
            ds64.append(WAVMarkerFixture.chunk("ds64", payload: payload))
        }

        var body = ds64
        body.append(afterDs64)

        var rf64 = Data()
        rf64.append(contentsOf: Array("RF64".utf8))
        rf64.append(le32(0xFFFF_FFFF))
        rf64.append(contentsOf: Array("WAVE".utf8))
        rf64.append(body)
        return rf64
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

private func le64(_ value: UInt64) -> Data {
    var value = value.littleEndian
    return Data(bytes: &value, count: 8)
}

private func be16(_ value: UInt16) -> Data {
    var value = value.bigEndian
    return Data(bytes: &value, count: 2)
}

private func be32(_ value: UInt32) -> Data {
    var value = value.bigEndian
    return Data(bytes: &value, count: 4)
}
