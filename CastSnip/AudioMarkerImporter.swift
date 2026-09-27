//
//  AudioMarkerImporter.swift
//  CastSnip
//

import Foundation
import AVFoundation

enum AudioMarkerImporter {
    enum Error: Swift.Error, LocalizedError {
        case unreadableRF64

        var errorDescription: String? {
            "Could not import RF64 markers. The file is missing a valid ds64 size table."
        }
    }

    static func chapters(from url: URL, durationMillis: UInt32) async throws -> [Chapter] {
        guard let header = fileHeader(url), header.count >= 12 else {
            return await movieChapters(from: url, durationMillis: durationMillis)
        }

        let magic = fourCC(header, 0)
        let form = fourCC(header, 8)
        if magic == "RIFF" || magic == "RF64", form == "WAVE" {
            return try waveChapters(from: url, durationMillis: durationMillis, isRF64: magic == "RF64")
        }
        if magic == "FORM", form == "AIFF" || form == "AIFC" {
            return aiffChapters(from: url, durationMillis: durationMillis)
        }
        return await movieChapters(from: url, durationMillis: durationMillis)
    }

    // MARK: - WAVE cue + LIST/adtl + iXML / RF64

    private static func waveChapters(from url: URL, durationMillis: UInt32, isRF64: Bool) throws -> [Chapter] {
        guard let walker = try? ChunkWalker(url: url, littleEndian: true) else { return [] }
        defer { walker.close() }

        if isRF64 {
            try applyRF64Sizes(walker)
        }

        var sampleRate: UInt32 = 0
        var cues: [CuePoint] = []
        var labels: [UInt32: String] = [:]
        var ixmlCues: [CuePoint] = []
        var ixmlLabels: [UInt32: String] = [:]

        while let chunk = walker.nextChunk() {
            if isRF64, chunk.size == 0xFFFF_FFFF {
                throw Error.unreadableRF64
            }
            switch chunk.id {
            case "fmt ":
                if let payload = walker.readPayload(of: chunk, limit: 16), payload.count >= 8 {
                    sampleRate = u32LE(payload, 4)
                }
            case "cue ":
                if let payload = walker.readPayload(of: chunk) {
                    cues.append(contentsOf: parseCueChunk(payload))
                }
            case "LIST":
                if let payload = walker.readPayload(of: chunk) {
                    mergeLabels(parseAdtlLabels(payload), into: &labels)
                }
            case "iXML":
                if let payload = walker.readPayload(of: chunk) {
                    parseIXML(payload, cues: &ixmlCues, labels: &ixmlLabels)
                }
            default:
                break
            }
            walker.skip(chunk)
        }

        let fromCues = makeChapters(cues: cues, labels: labels, sampleRate: sampleRate, durationMillis: durationMillis)
        if !fromCues.isEmpty {
            return fromCues
        }
        return makeChapters(cues: ixmlCues, labels: ixmlLabels, sampleRate: sampleRate, durationMillis: durationMillis)
    }

    private static func applyRF64Sizes(_ walker: ChunkWalker) throws {
        guard let chunk = walker.nextChunk(), chunk.id == "ds64" else {
            throw Error.unreadableRF64
        }
        guard let payload = walker.readPayload(of: chunk), let ds64 = parseDs64(payload) else {
            throw Error.unreadableRF64
        }
        walker.sizeOverrides["data"] = ds64.dataSize
        for (id, size) in ds64.table {
            walker.sizeOverrides[id] = size
        }
        walker.skip(chunk)
    }

    private static func parseDs64(_ data: Data) -> (dataSize: UInt64, table: [String: UInt64])? {
        guard data.count >= 28 else { return nil }
        let dataSize = u64LE(data, 8)
        let tableLength = Int(u32LE(data, 24))
        var table: [String: UInt64] = [:]
        var offset = 28
        for _ in 0..<tableLength {
            guard offset + 12 <= data.count else { return nil }
            table[fourCC(data, offset)] = u64LE(data, offset + 4)
            offset += 12
        }
        return (dataSize, table)
    }

    private static func parseIXML(_ data: Data, cues: inout [CuePoint], labels: inout [UInt32: String]) {
        let trimmed = data.prefix { $0 != 0 }
        guard !trimmed.isEmpty, let document = try? XMLDocument(data: Data(trimmed)) else { return }
        let nodes = (try? document.nodes(forXPath: "//SYNC_POINT")) ?? []
        for (index, node) in nodes.enumerated() {
            guard let element = node as? XMLElement else { continue }
            let low = UInt64(child(element, "SYNC_POINT_LOW") ?? "0") ?? 0
            let high = UInt64(child(element, "SYNC_POINT_HIGH") ?? "0") ?? 0
            let id = UInt32(index + 1)
            cues.append(CuePoint(id: id, sample: low | (high << 32)))
            if let name = child(element, "SYNC_POINT_COMMENT"), !name.isEmpty {
                labels[id] = name
            }
        }
    }

    private static func child(_ element: XMLElement, _ name: String) -> String? {
        element.elements(forName: name).first?.stringValue?
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func parseCueChunk(_ data: Data) -> [CuePoint] {
        guard data.count >= 4 else { return [] }
        let count = Int(u32LE(data, 0))
        var offset = 4
        var cues: [CuePoint] = []
        for _ in 0..<count {
            guard offset + 24 <= data.count else { break }
            let id = u32LE(data, offset)
            let position = u32LE(data, offset + 4)
            let sampleOffset = u32LE(data, offset + 20)
            cues.append(CuePoint(id: id, sample: UInt64(sampleOffset != 0 ? sampleOffset : position)))
            offset += 24
        }
        return cues
    }

    private static func parseAdtlLabels(_ data: Data) -> [UInt32: String] {
        guard data.count >= 4, fourCC(data, 0) == "adtl" else { return [:] }
        var labels: [UInt32: String] = [:]
        var offset = 4
        while offset + 8 <= data.count {
            let id = fourCC(data, offset)
            let size = Int(u32LE(data, offset + 4))
            let payloadStart = offset + 8
            guard size >= 0, payloadStart <= data.count else { break }
            let payloadEnd = min(payloadStart + size, data.count)
            if id == "labl", payloadEnd - payloadStart >= 4 {
                let cueID = u32LE(data, payloadStart)
                let nameData = data.subdata(in: (payloadStart + 4)..<payloadEnd)
                if let name = cString(nameData), !name.isEmpty {
                    labels[cueID] = name
                }
            }
            offset = payloadStart + size + (size % 2)
        }
        return labels
    }

    // MARK: - AIFF MARK

    private static func aiffChapters(from url: URL, durationMillis: UInt32) -> [Chapter] {
        guard let walker = try? ChunkWalker(url: url, littleEndian: false) else { return [] }
        defer { walker.close() }

        var sampleRate: UInt32 = 0
        var cues: [CuePoint] = []
        var labels: [UInt32: String] = [:]

        while let chunk = walker.nextChunk() {
            switch chunk.id {
            case "COMM":
                if let payload = walker.readPayload(of: chunk, limit: 18), payload.count >= 18 {
                    sampleRate = UInt32(extended80(payload.subdata(in: 8..<18)).rounded())
                }
            case "MARK":
                if let payload = walker.readPayload(of: chunk) {
                    parseMarkChunk(payload, cues: &cues, labels: &labels)
                }
            case "cue ":
                if let payload = walker.readPayload(of: chunk) {
                    cues.append(contentsOf: parseCueChunk(payload))
                }
            case "LIST":
                if let payload = walker.readPayload(of: chunk) {
                    mergeLabels(parseAdtlLabels(payload), into: &labels)
                }
            default:
                break
            }
            walker.skip(chunk)
        }

        return makeChapters(cues: cues, labels: labels, sampleRate: sampleRate, durationMillis: durationMillis)
    }

    private static func parseMarkChunk(_ data: Data, cues: inout [CuePoint], labels: inout [UInt32: String]) {
        guard data.count >= 2 else { return }
        let count = Int(u16BE(data, 0))
        var offset = 2
        for _ in 0..<count {
            guard offset + 6 <= data.count else { break }
            let id = UInt32(u16BE(data, offset))
            let sample = u32BE(data, offset + 2)
            offset += 6
            guard offset < data.count else {
                cues.append(CuePoint(id: id, sample: UInt64(sample)))
                break
            }
            let length = Int(data[offset])
            offset += 1
            let nameEnd = min(offset + length, data.count)
            let name = String(data: data.subdata(in: offset..<nameEnd), encoding: .utf8)
                ?? String(data: data.subdata(in: offset..<nameEnd), encoding: .isoLatin1)
                ?? ""
            offset = nameEnd
            if (1 + length) % 2 == 1 {
                offset += 1
            }
            cues.append(CuePoint(id: id, sample: UInt64(sample)))
            if !name.isEmpty {
                labels[id] = name
            }
        }
    }

    // MARK: - M4A chapter / timed metadata

    private static func movieChapters(from url: URL, durationMillis: UInt32) async -> [Chapter] {
        let ext = url.pathExtension.lowercased()
        let movieExtensions: Set<String> = ["m4a", "m4b", "mp4", "aac"]
        guard movieExtensions.contains(ext) else { return [] }

        let asset = AVURLAsset(url: url)
        var groups: [AVTimedMetadataGroup] = []
        do {
            if let locale = try await asset.load(.availableChapterLocales).first {
                groups = try await asset.loadChapterMetadataGroups(
                    withTitleLocale: locale,
                    containingItemsWithCommonKeys: []
                )
            }
            if groups.isEmpty {
                groups = try await asset.loadChapterMetadataGroups(
                    bestMatchingPreferredLanguages: Locale.preferredLanguages
                )
            }
        } catch {
            return []
        }
        guard !groups.isEmpty else { return [] }
        return await chapters(from: groups, durationMillis: durationMillis, asset: asset)
    }

    private static func chapters(
        from groups: [AVTimedMetadataGroup],
        durationMillis: UInt32,
        asset: AVURLAsset
    ) async -> [Chapter] {
        let duration = await resolvedDuration(durationMillis, asset: asset)
        var points: [(title: String, start: UInt32)] = []
        for (index, group) in groups.enumerated() {
            let item = group.items.first(where: { $0.commonKey == .commonKeyTitle }) ?? group.items.first
            let loaded = try? await item?.load(.stringValue)
            let title = loaded.flatMap { $0.isEmpty ? nil : $0 } ?? "Marker \(index + 1)"
            points.append((title: title, start: millis(from: group.timeRange.start)))
        }
        return makeChapters(points: points, durationMillis: duration)
    }

    private static func resolvedDuration(_ durationMillis: UInt32, asset: AVURLAsset) async -> UInt32 {
        if durationMillis > 0 { return durationMillis }
        guard let time = try? await asset.load(.duration) else { return 0 }
        let seconds = CMTimeGetSeconds(time)
        guard seconds.isFinite, seconds > 0 else { return 0 }
        return UInt32((seconds * 1000).rounded())
    }

    private static func millis(from time: CMTime) -> UInt32 {
        let seconds = CMTimeGetSeconds(time)
        guard seconds.isFinite, seconds >= 0 else { return 0 }
        return UInt32((seconds * 1000).rounded())
    }

    // MARK: - Shared chapter building

    private static func makeChapters(
        cues: [CuePoint],
        labels: [UInt32: String],
        sampleRate: UInt32,
        durationMillis: UInt32
    ) -> [Chapter] {
        guard !cues.isEmpty, sampleRate > 0 else { return [] }
        let sorted = cues.sorted { $0.sample < $1.sample }
        return makeChapters(
            points: sorted.enumerated().map { index, cue in
                let title = labels[cue.id].flatMap { $0.isEmpty ? nil : $0 } ?? "Marker \(index + 1)"
                return (title: title, start: millis(samples: cue.sample, sampleRate: sampleRate))
            },
            durationMillis: durationMillis
        )
    }

    private static func makeChapters(points: [(title: String, start: UInt32)], durationMillis: UInt32) -> [Chapter] {
        points.enumerated().map { index, point in
            let end = index + 1 < points.count ? points[index + 1].start : durationMillis
            return Chapter(
                title: point.title,
                startTime: point.start,
                endTime: end,
                podcastDuration: durationMillis
            )
        }
    }

    private static func millis(samples: UInt64, sampleRate: UInt32) -> UInt32 {
        guard sampleRate > 0 else { return 0 }
        let value = (samples * 1_000) / UInt64(sampleRate)
        return value > UInt64(UInt32.max) ? .max : UInt32(value)
    }

    private static func mergeLabels(_ extra: [UInt32: String], into labels: inout [UInt32: String]) {
        for (id, name) in extra {
            labels[id] = name
        }
    }

    private static func cString(_ data: Data) -> String? {
        let trimmed = data.prefix { $0 != 0 }
        guard !trimmed.isEmpty else { return nil }
        return String(bytes: trimmed, encoding: .utf8)
            ?? String(bytes: trimmed, encoding: .isoLatin1)
    }

    private static func fileHeader(_ url: URL) -> Data? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }
        return try? handle.read(upToCount: 12)
    }

    private static func fourCC(_ data: Data, _ offset: Int) -> String {
        guard offset + 4 <= data.count else { return "" }
        return String(bytes: data[offset..<(offset + 4)], encoding: .isoLatin1) ?? ""
    }

    private static func u16BE(_ data: Data, _ offset: Int) -> UInt16 {
        UInt16(data[offset]) << 8 | UInt16(data[offset + 1])
    }

    private static func u32LE(_ data: Data, _ offset: Int) -> UInt32 {
        UInt32(data[offset])
            | UInt32(data[offset + 1]) << 8
            | UInt32(data[offset + 2]) << 16
            | UInt32(data[offset + 3]) << 24
    }

    private static func u64LE(_ data: Data, _ offset: Int) -> UInt64 {
        UInt64(u32LE(data, offset)) | UInt64(u32LE(data, offset + 4)) << 32
    }

    private static func u32BE(_ data: Data, _ offset: Int) -> UInt32 {
        UInt32(data[offset]) << 24
            | UInt32(data[offset + 1]) << 16
            | UInt32(data[offset + 2]) << 8
            | UInt32(data[offset + 3])
    }

    /// AIFF COMM sample rate is an 80-bit IEEE extended float.
    private static func extended80(_ data: Data) -> Double {
        guard data.count >= 10 else { return 0 }
        let bytes = Array(data.prefix(10))
        let sign = (bytes[0] & 0x80) != 0
        let exponent = (Int(bytes[0] & 0x7F) << 8) | Int(bytes[1])
        var mantissa: UInt64 = 0
        for i in 2..<10 {
            mantissa = (mantissa << 8) | UInt64(bytes[i])
        }
        if exponent == 0 && mantissa == 0 { return 0 }
        if exponent == 0x7FFF { return 0 }
        let value = Double(mantissa) * pow(2.0, Double(exponent - 16383 - 63))
        return sign ? -value : value
    }
}

private struct CuePoint {
    var id: UInt32
    var sample: UInt64
}

/// Walks RIFF/IFF chunks without loading the audio payload into memory.
private final class ChunkWalker {
    private let handle: FileHandle
    private let fileSize: UInt64
    private let littleEndian: Bool
    var sizeOverrides: [String: UInt64] = [:]

    init(url: URL, littleEndian: Bool) throws {
        handle = try FileHandle(forReadingFrom: url)
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        fileSize = attributes[.size] as? UInt64 ?? 0
        self.littleEndian = littleEndian
        try handle.seek(toOffset: 12)
    }

    func close() {
        try? handle.close()
    }

    func nextChunk() -> (id: String, size: UInt64, payloadStart: UInt64)? {
        do {
            let offset = try handle.offset()
            guard offset + 8 <= fileSize else { return nil }
            guard let header = try handle.read(upToCount: 8), header.count == 8 else { return nil }
            let id = String(bytes: header[0..<4], encoding: .isoLatin1) ?? ""
            let rawSize = littleEndian
                ? UInt32(header[4]) | UInt32(header[5]) << 8 | UInt32(header[6]) << 16 | UInt32(header[7]) << 24
                : UInt32(header[4]) << 24 | UInt32(header[5]) << 16 | UInt32(header[6]) << 8 | UInt32(header[7])
            let size = resolvedSize(id: id, raw: rawSize)
            let payloadStart = try handle.offset()
            return (id, size, payloadStart)
        } catch {
            return nil
        }
    }

    func readPayload(of chunk: (id: String, size: UInt64, payloadStart: UInt64), limit: Int? = nil) -> Data? {
        do {
            try handle.seek(toOffset: chunk.payloadStart)
            let count = Int(min(chunk.size, UInt64(limit ?? Int.max), UInt64(Int.max)))
            guard count > 0 else { return Data() }
            return try handle.read(upToCount: count)
        } catch {
            return nil
        }
    }

    func skip(_ chunk: (id: String, size: UInt64, payloadStart: UInt64)) {
        var next = chunk.payloadStart + chunk.size
        if chunk.size % 2 == 1 {
            next += 1
        }
        try? handle.seek(toOffset: min(next, fileSize))
    }

    private func resolvedSize(id: String, raw: UInt32) -> UInt64 {
        if raw == 0xFFFF_FFFF, let override = sizeOverrides[id] {
            return override
        }
        return UInt64(raw)
    }
}
